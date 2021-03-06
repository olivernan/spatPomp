library(spatPomp)
context("test spatPomp()")

U = 6
dt = 2/365

birth_lag <- 3*26  # delay until births hit susceptibles, in biweeks

# pre-vaccine biweekly measles reports for the largest 40 UK cities, sorted by size
data(measlesUK)
measlesUK$city<-as.character(measlesUK$city)

# Note: check for outliers, c.f. He et al (2010)


######## code for data cleaning: only re-run if dataset changes ######
if(0){
# datafile for measles spatPomp
# derived from measlesUKUS.csv from
# https://datadryad.org/resource/doi:10.5061/dryad.r4q34
# US data come from Project Tycho.
# England and Wales data are the city of London plus the largest 39 cities that were more than 50km from London.
# cases is reported measles cases per biweek
# births is estimated recruitment of susceptibles per biweek
library(magrittr)
library(dplyr)
read.csv("../../measles/measlesUKUS.csv",stringsAsFactors=FALSE) %>% subset(country=="UK") -> x
library(dplyr)
x %>%
group_by(loc) %>%
mutate(meanPop = mean(pop)) %>%
ungroup() %>%
arrange(desc(meanPop),decimalYear) -> x1
x1 %>% transmute(year=decimalYear,city=loc,cases=cases,pop=pop,births=rec) -> x2
# the R package csv format
# from https://cran.r-project.org/doc/manuals/R-exts.html#Data-in-packages
write.table(file="measlesUK.csv",sep = ";",row.names=F,x2)
y <- x1[x1$decimalYear==1944,c("loc","lon","lat","meanPop")]
y1 <- transmute(y,city=loc,lon,lat,meanPop)
write.table(file="city_data_UK.csv",sep=";",row.names=F,y1)
}
####################################################################

cities <- unique(measlesUK$city)[1:U]
measles_cases <- measlesUK[measlesUK$city %in% cities,c("year","city","cases")]
measles_cases <- measles_cases[measles_cases$year>1949.99,]
measles_covar <- measlesUK[measlesUK$city %in% cities,c("year","city","pop","births")]
u <- split(measles_covar$births,measles_covar$city)
v <- sapply(u,function(x){c(rep(NA,birth_lag),x[1:(length(x)-birth_lag)])})
measles_covar$lag_birthrate <- as.vector(v[,cities])*26
measles_covar$births<- NULL
measles_covarnames <- paste0(rep(c("pop","lag_birthrate"),each=U),1:U)

data(city_data_UK)
# Distance between two points on a sphere radius R
# Adapted from geosphere package
distHaversine <- function (p1, p2, r = 6378137)
{
toRad <- pi/180
p1 <- p1 * toRad
p2 <- p2 * toRad
p = cbind(p1[, 1], p1[, 2], p2[, 1], p2[, 2], as.vector(r))
dLat <- p[, 4] - p[, 2]
dLon <- p[, 3] - p[, 1]
a <- sin(dLat/2) * sin(dLat/2) + cos(p[, 2]) * cos(p[, 4]) *
sin(dLon/2) * sin(dLon/2)
a <- pmin(a, 1)
dist <- 2 * atan2(sqrt(a), sqrt(1 - a)) * p[, 5]
return(as.vector(dist))
}

long_lat <- city_data_UK[1:U,c("lon","lat")]
dmat <- matrix(0,U,U)
for(u1 in 1:U) {
for(u2 in 1:U) {
dmat[u1,u2] <- round(distHaversine(long_lat[u1,],long_lat[u2,]) / 1609.344,1)
}
}

p <- city_data_UK$meanPop[1:U]
v_by_g <- matrix(0,U,U)
dist_mean <- sum(dmat)/(U*(U-1))
p_mean <- mean(p)
for(u1 in 2:U){
for(u2 in 1:(u1-1)){
v_by_g[u1,u2] <- (dist_mean*p[u1]*p[u2]) / (dmat[u1,u2] * p_mean^2)
v_by_g[u2,u1] <- v_by_g[u1,u2]
}
}
to_C_array <- function(v)paste0("{",paste0(v,collapse=","),"}")
v_by_g_C_rows <- apply(v_by_g,1,to_C_array)
v_by_g_C_array <- to_C_array(v_by_g_C_rows)
v_by_g_C <- Csnippet(paste0("const double v_by_g[",U,"][",U,"] = ",v_by_g_C_array,"; "))

measles_globals <- Csnippet(
paste0("const int U = ",U,"; \n ", v_by_g_C)
)

measles_unit_statenames <- c('S','E','I','R','C','W')
#measles_unit_statenames <- c('S','E','I','R','Acc','C','W')

measles_statenames <- paste0(rep(measles_unit_statenames,each=U),1:U)
measles_IVPnames <- paste0(measles_statenames[1:(4*U)],"_0")
measles_RPnames <- c("alpha","iota","R0","cohort","amplitude","gamma","sigma","mu","sigmaSE","rho","psi","g")
measles_paramnames <- c(measles_RPnames,measles_IVPnames)

measles_rprocess <- Csnippet('
                         double beta, br, seas, foi, dw, births;
                         double rate[6], trans[6];
                         double *S = &S1;
                         double *E = &E1;
                         double *I = &I1;
                         double *R = &R1;
                         double *C = &C1;
                         double *W = &W1;
                         double powVec[U];
                         //double *Acc = &Acc1;
                         const double *pop = &pop1;
                         const double *lag_birthrate = &lag_birthrate1;
                         int obstime = 0;
                         int u,v;
                         // obstime variable to be used later. See note on if(obstime) conditional
                         //if(fabs(((t-floor(t)) / (2.0/52.0)) - (float)(round((t-floor(t)) / (2.0/52.0)))) < 0.001){
                         //obstime = 1;
                         //Rprintf("t=%f is an observation time\\n",t);
                         //}
                         // term-time seasonality
                         t = (t-floor(t))*365.25;
                         if ((t>=7&&t<=100) || (t>=115&&t<=199) || (t>=252&&t<=300) || (t>=308&&t<=356))
                         seas = 1.0+amplitude*0.2411/0.7589;
                         else
                         seas = 1.0-amplitude;

                         // transmission rate
                         beta = R0*(gamma+mu)*seas;

                         // pre-computing this saves substantial time
                         for (u = 0 ; u < U ; u++) {
                         powVec[u] = pow(I[u]/pop[u],alpha);
                         }

                         for (u = 0 ; u < U ; u++) {

                         // cohort effect
                         if (fabs(t-floor(t)-251.0/365.0) < 0.5*dt)
                         br = cohort*lag_birthrate[u]/dt + (1-cohort)*lag_birthrate[u];
                         else
                         br = (1.0-cohort)*lag_birthrate[u];

                         // expected force of infection
                         foi = pow( (I[u]+iota)/pop[u],alpha);
                         // we follow Park and Ionides (2019) and raise pop to the alpha power
                         // He et al (2010) did not do this.

                         for (v=0; v < U ; v++) {
                         if(v != u)
                         foi += g * v_by_g[u][v] * (powVec[v] - powVec[u]) / pop[u];
                         }
                         // white noise (extrademographic stochasticity)
                         dw = rgammawn(sigmaSE,dt);

                         rate[0] = beta*foi*dw/dt;  // stochastic force of infection

                         // These rates could be outside the u loop if all parameters are shared between units
                         rate[1] = mu;			    // natural S death
                         rate[2] = sigma;		  // rate of ending of latent stage
                         rate[3] = mu;			    // natural E death
                         rate[4] = gamma;		  // recovery
                         rate[5] = mu;			    // natural I death

                         // Poisson births
                         births = rpois(br*dt);

                         // transitions between classes
                         reulermultinom(2,S[u],&rate[0],dt,&trans[0]);
                         reulermultinom(2,E[u],&rate[2],dt,&trans[2]);
                         reulermultinom(2,I[u],&rate[4],dt,&trans[4]);

                         S[u] += births   - trans[0] - trans[1];
                         E[u] += trans[0] - trans[2] - trans[3];
                         I[u] += trans[2] - trans[4] - trans[5];
                         R[u] = pop[u] - S[u] - E[u] - I[u];
                         W[u] += (dw - dt)/sigmaSE;  // standardized i.i.d. white noise
                         C[u] += trans[4];           // true incidence

                         }
                         ')

measles_dmeasure <- Csnippet("
                         const double *C = &C1;
                         const double *cases = &cases1;
                         double m,v;
                         double tol = 1e-300;
                         int u;

                         lik = 0;
                         for (u = 0; u < U; u++) {
                         m = rho*C[u];
                         v = m*(1.0-rho+psi*psi*m);
                         if (cases[u] > 0.0) {
                         lik += log(pnorm(cases[u]+0.5,m,sqrt(v)+tol,1,0)-pnorm(cases[u]-0.5,m,sqrt(v)+tol,1,0)+tol);
                         } else {
                         lik += log(pnorm(cases[u]+0.5,m,sqrt(v)+tol,1,0)+tol);
                         }
                         }
                         if(!give_log) lik = (lik > log(tol)) ? exp(lik) : tol;
                         ")

measles_rmeasure <- Csnippet("
                         const double *C = &C1;
                         double *cases = &cases1;
                         double m,v;
                         double tol = 1.0e-300;
                         int u;

                         for (u = 0; u < U; u++) {
                         m = rho*C[u];
                         v = m*(1.0-rho+psi*psi*m);
                         cases[u] = rnorm(m,sqrt(v)+tol);
                         if (cases[u] > 0.0) {
                         cases[u] = nearbyint(cases[u]);
                         } else {
                         cases[u] = 0.0;
                         }
                         }
                         ")

measles_unit_dmeasure <- Csnippet('
                              // consider adding 1 to the variance for the case C = 0
                              double m = rho*C;
                              double v = m*(1.0-rho+psi*psi*m);
                              double tol = 1e-300;
                              if (cases > 0.0) {
                              lik = pnorm(cases+0.5,m,sqrt(v)+tol,1,0)-pnorm(cases-0.5,m,sqrt(v)+tol,1,0)+tol;
                              } else {
                              lik = pnorm(cases+0.5,m,sqrt(v)+tol,1,0)+tol;
                              }
                              if(give_log) lik = log(lik);
                              ')

measles_unit_emeasure <- Csnippet("
                              ey = rho*C;
                              ")

measles_unit_vmeasure <- Csnippet("
                              //consider adding 1 to the variance for the case C = 0
                              double m;
                              m = rho*C;
                              vc = m*(1.0-rho+psi*psi*m);
                              ")

measles_unit_mmeasure <- Csnippet("
                              double binomial_var;
                              double m;
                              m = rho*C;
                              binomial_var = rho*(1-rho)*C;
                              if(vc > binomial_var) {
                              M_psi = sqrt(vc - binomial_var)/m;
                              }
                              ")

measles_rinit <- Csnippet("
                      double *S = &S1;
                      double *E = &E1;
                      double *I = &I1;
                      double *R = &R1;
                      double *C = &C1;
                      double *W = &W1;
                      //double *Acc = &Acc1;
                      const double *S_0 = &S1_0;
                      const double *E_0 = &E1_0;
                      const double *I_0 = &I1_0;
                      const double *R_0 = &R1_0;
                      //const double *Acc_0 = &Acc1_0;
                      const double *pop = &pop1;
                      double m;
                      int u;
                      for (u = 0; u < U; u++) {
                      m = pop[u]/(S_0[u]+E_0[u]+I_0[u]+R_0[u]);
                      S[u] = nearbyint(m*S_0[u]);
                      E[u] = nearbyint(m*E_0[u]);
                      I[u] = nearbyint(m*I_0[u]);
                      R[u] = nearbyint(m*R_0[u]);
                      W[u] = 0;
                      C[u] = 0;
                      //Acc[u] = Acc_0[u];
                      }
                      ")

measles_skel <- Csnippet('
                     double beta, br, seas, foi;
                     double *S = &S1;
                     double *E = &E1;
                     double *I = &I1;
                     double *R = &R1;
                     double *C = &C1;
                     double *W = &W1;
                     double *DS = &DS1;
                     double *DE = &DE1;
                     double *DI = &DI1;
                     double *DR = &DR1;
                     //double *DAcc = &DAcc1;
                     double *DC = &DC1;
                     double *DW = &DW1;
                     double powVec[U];
                     //double *Acc = &Acc1;
                     const double *pop = &pop1;
                     const double *lag_birthrate = &lag_birthrate1;
                     int u,v;
                     int obstime = 0;
                     //if(fabs(((t-floor(t)) / (2.0/52.0)) - (float)(round((t-floor(t)) / (2.0/52.0)))) < 0.001){
                     //obstime = 1;
                     //}

                     // term-time seasonality
                     t = (t-floor(t))*365.25;
                     if ((t>=7&&t<=100) || (t>=115&&t<=199) || (t>=252&&t<=300) || (t>=308&&t<=356))
                     seas = 1.0+amplitude*0.2411/0.7589;
                     else
                     seas = 1.0-amplitude;

                     // transmission rate
                     beta = R0*(gamma+mu)*seas;

                     // pre-computing this saves substantial time
                     for (u = 0 ; u < U ; u++) {
                     powVec[u] = pow(I[u]/pop[u],alpha);
                     }

                     for (u = 0 ; u < U ; u++) {
                     //if(obstime != 1){
                     //C[u] = Acc[u];
                     //}
                     // cannot readily put the cohort effect into a vectorfield for the skeleton
                     // therefore, we ignore it here.
                     // this is okay as long as the skeleton is being used for short-term forecasts
                     //    br = lag_birthrate[u];

                     // cohort effect, added back in with cohort arriving over a time interval 0.05yr
                     if (fabs(t-floor(t)-251.0/365.0) < 0.5*0.05)
                     br = cohort*lag_birthrate[u]/0.05 + (1-cohort)*lag_birthrate[u];
                     else
                     br = (1.0-cohort)*lag_birthrate[u];

                     foi = pow( (I[u]+iota)/pop[u],alpha);
                     for (v=0; v < U ; v++) {
                     if(v != u)
                     foi += g * v_by_g[u][v] * (powVec[v] - powVec[u]) / pop[u];
                     }

                     DS[u] = br - (beta*foi + mu)*S[u];
                     DE[u] = beta*foi*S[u] - (sigma+mu)*E[u];
                     DI[u] = sigma*E[u] - (gamma+mu)*I[u];
                     DR[u] = gamma*I[u] - mu*R[u];
                     DW[u] = 0;
                     DC[u] = gamma*I[u];
                     //DAcc[u] = 0;
                     }
                     ')


m <- spatPomp2(measles_cases,
         units = "city",
         times = "year",
         t0 = min(measles_cases$year)-1/26,
         unit_statenames = measles_unit_statenames,
         covar = measles_covar,
         tcovar = "year",
         rprocess=euler(measles_rprocess, delta.t=dt),
         skeleton=vectorfield(measles_skel),
         accumvars = c(paste0("C",1:U),paste0("W",1:U)),
         paramnames=measles_paramnames,
         covarnames=measles_covarnames,
         globals=measles_globals,
         rinit=measles_rinit,
         dmeasure=measles_dmeasure,
         unit_emeasure=measles_unit_emeasure,
         unit_mmeasure=measles_unit_mmeasure,
         unit_vmeasure=measles_unit_vmeasure,
         rmeasure=measles_rmeasure,
         unit_dmeasure=measles_unit_dmeasure
)

m_partial <- spatPomp2(measles_cases,
                       units = "city",
                       times = "year",
                       t0 = min(measles_cases$year)-1/26,
                       unit_statenames = measles_unit_statenames,
                       covar = measles_covar,
                       tcovar = "year",
                       rprocess=euler(measles_rprocess, delta.t=dt),
                       accumvars = c(paste0("C",1:U),paste0("W",1:U)),
                       paramnames=measles_paramnames,
                       covarnames=measles_covarnames,
                       globals=measles_globals,
                       rinit=measles_rinit,
                       dmeasure=measles_dmeasure,
                       rmeasure=measles_rmeasure,
                       unit_emeasure=measles_unit_emeasure,
                       unit_dmeasure=measles_unit_dmeasure
)

measles_unit_emeasure2 <- Csnippet("
                              ey = rho*C;
                              ")
# try with unit_emeasure2
m_partial2 <- spatPomp2(m_partial,
                        unit_emeasure=measles_unit_emeasure2,
                        paramnames = c("rho"),
                        statenames = c("C")
)
