% Generated by roxygen2: do not edit by hand
% Please edit documentation in R/spatPomp.R
\name{spatPomp}
\alias{spatPomp}
\title{Constructor of the basic spatPomp object}
\usage{
spatPomp(data, units, times, covar, tcovar, t0, ..., unit_emeasure,
  unit_mmeasure, unit_vmeasure, unit_dmeasure, unit_rmeasure,
  unit_statenames, rprocess, rmeasure, dprocess, dmeasure, skeleton, rinit,
  cdir, cfile, shlib.args, userdata, PACKAGE, globals, statenames,
  paramnames, obstypes, accumvars, covarnames, shared_covarnames, partrans,
  verbose = getOption("verbose", FALSE))
}
\arguments{
\item{data}{either a data frame holding the spatiotemporal data,
or an object of class \sQuote{spatPomp},
i.e., the output of another \pkg{spatPomp} calculation.}

\item{times}{the times at which observations are made.
\code{times} must indicate the column of observation times by name or index.
The time vector must be numeric and non-decreasing.
Internally, \code{data} will be internally coerced to an array with storage-mode \code{double}.}

\item{covar}{optional covariate table, constructed using \code{\link{covariate_table}}.

If a covariate table is supplied, then the value of each of the covariates is interpolated as needed.
The resulting interpolated values are made available to the appropriate basic components.
See the documentation for \code{\link{covariate_table}} for details.}

\item{t0}{The zero-time, i.e., the time of the initial state.
This must be no later than the time of the first observation, i.e., \code{t0 <= times[1]}.}

\item{...}{additional arguments supply new or modify existing model characteristics or components.
See \code{\link{pomp}} for a full list of recognized arguments.

When named arguments not recognized by \code{\link{pomp}} are provided, these are made available to all basic components via the so-called \dfn{userdata} facility.
This allows the user to pass information to the basic components outside of the usual routes of covariates (\code{covar}) and model parameters (\code{params}).
See \link[=userdata]{?userdata} for information on how to use this facility.}

\item{unit_emeasure}{Evaluator of the expected measurement given the latent states and model parameters. The \code{unit} variable is pre-defined, which allows the user to specify differing specifications for each unit using \code{if} conditions.
Only Csnippets are accepted. The Csnippet should assign the scalar approximation to the expected measurement to the pre-defined variable \code{ey} given the latent state and the parameters.
For more information, see the examples section below.}

\item{unit_mmeasure}{Evaluator of a moment-matched measurement variance parameter (like the standard deviation parameter of a normal distribution or the size parameter of a negative binomial distribution) given an empirical variance estimate, the latent states and all model parameters.
Only Csnippets are accepted. The Csnippet should assign the scalar approximation to the measurement variance parameter to the pre-defined variable corresponding to that parameter, which has been predefined with a \code{M_} prefix. For instance, if the moment-matched parameter is \code{psi}, then the user should assign \code{M_psi} to the moment-matched value.
For more information, see the examples section below.}

\item{unit_vmeasure}{Evaluator of the theoretical measurement variance given the latent states and model parameters. The \code{unit} variable is pre-defined, which allows the user to specify differing specifications for each unit using \code{if} conditions.
Only Csnippets are accepted. The Csnippet should assign the scalar approximation to the measurement variance to the pre-defined variable \code{vc} given the latent state and the parameters.
For more information, see the examples section below.}

\item{unit_dmeasure}{Evaluator of the unit measurement model density given the measurement, the latent states and model parameters. The \code{unit} variable is pre-defined, which allows the user to specify differing specifications for each unit using \code{if} conditions.
Only Csnippets are accepted. The Csnippet should assign the scalar measurement density to the pre-defined variable \code{lik}. The user is encouraged to provide a logged density in an \code{if} condition that checks whether the predefined \code{give_log} variable is true.
For more information, see the examples section below.}

\item{unit_rmeasure}{Simulator of the unit measurement model given the latent states and the model parameters.
The \code{unit} variable is pre-defined, which allows the user to specify differing specifications for each unit using \code{if} conditions.
Only Csnippets are accepted. The Csnippet should assign the scalar measurement density to the pre-defined which corresponds to the name of the observation for each unit (e.g. \code{cases} for the measles spatPomp example).
For more information, see the examples section below.}

\item{rprocess}{simulator of the latent state process, specified using one of the \link[=rprocess_spec]{rprocess plugins}.
Setting \code{rprocess=NULL} removes the latent-state simulator.
For more information, \link[=rprocess_spec]{see ?rprocess_spec for the documentation on these plugins}.}

\item{rmeasure}{simulator of the measurement model, specified either as a C snippet, an \R function, or the name of a pre-compiled native routine available in a dynamically loaded library.
Setting \code{rmeasure=NULL} removes the measurement model simulator.
For more information, see \link[=rmeasure_spec]{?rmeasure_spec}.}

\item{dprocess}{optional;
specification of the probability density evaluation function of the unobserved state process.
Setting \code{dprocess=NULL} removes the latent-state density evaluator.
For more information, see \link[=dprocess_spec]{?dprocess_spec}.}

\item{dmeasure}{evaluator of the measurement model density, specified either as a C snippet, an \R function, or the name of a pre-compiled native routine available in a dynamically loaded library.
Setting \code{dmeasure=NULL} removes the measurement density evaluator.
For more information, see \link[=dmeasure_spec]{?dmeasure_spec}.}

\item{skeleton}{optional; the deterministic skeleton of the unobserved state process.
Depending on whether the model operates in continuous or discrete time, this is either a vectorfield or a map.
Accordingly, this is supplied using either the \code{\link[=skeleton_spec]{vectorfield}} or \code{\link[=skeleton_spec]{map}} fnctions.
For more information, see \link[=skeleton_spec]{?skeleton_spec}.
Setting \code{skeleton=NULL} removes the deterministic skeleton.}

\item{rinit}{simulator of the initial-state distribution.
This can be furnished either as a C snippet, an \R function, or the name of a pre-compiled native routine available in a dynamically loaded library.
Setting \code{rinit=NULL} sets the initial-state simulator to its default.
For more information, see \link[=rinit_spec]{?rinit_spec}.}

\item{cdir}{optional character variable.
\code{cdir} specifies the name of the directory within which C snippet code will be compiled.
By default, this is in a temporary directory specific to the \R session.
One can also set this directory using the \code{pomp_cdir} option.}

\item{cfile}{optional character variable.
\code{cfile} gives the name of the file (in directory \code{cdir}) into which C snippet codes will be written.
By default, a random filename is used.
If the chosen filename would result in over-writing an existing file, an error is generated.}

\item{shlib.args}{optional character variables.
Command-line arguments to the \code{R CMD SHLIB} call that compiles the C snippets.}

\item{PACKAGE}{optional character;
the name (without extension) of the external, dynamically loaded library in which any native routines are to be found.
This is only useful if one or more of the model components has been specified using a precompiled dynamically loaded library;
it is not used for any component specified using C snippets.
\code{PACKAGE} can name at most one library.}

\item{globals}{optional character;
arbitrary C code that will be hard-coded into the shared-object library created when  C snippets are provided.
If no C snippets are used, \code{globals} has no effect.}

\item{statenames}{optional character vector;
names of the latent state variables.
It is typically only necessary to supply \code{statenames} when C snippets are in use.}

\item{paramnames}{optional character vector;
names of model parameters.
It is typically only necessary to supply \code{paramnames} when C snippets are in use.}

\item{accumvars}{optional character vector;
contains the names of accumulator variables.
See \link[=accumulators]{?accumulators} for a definition and discussion of accumulator variables.}

\item{covarnames}{optional character vector;
names of the covariates.
It is not usually necessary to specify \code{covarnames} since, by default,
these are read from the names of the covariates.}

\item{partrans}{optional parameter transformations, constructed using \code{\link{parameter_trans}}.

Many algorithms for parameter estimation search an unconstrained space of parameters.
When working with such an algorithm and a model for which the parameters are constrained, it can be useful to transform parameters.
One should supply the \code{partrans} argument via a call to \code{\link{parameter_trans}}.
For more information, see \link[=parameter_trans]{?parameter_trans}.
Setting \code{partrans=NULL} removes the parameter transformations, i.e., sets them to the identity transformation.}

\item{verbose}{logical; if \code{TRUE}, diagnostic messages will be printed to the console.}
}
\description{
This function constructs a \sQuote{spatPomp} object, encoding a spatiotemporal partially observed Markov process (\acronym{SpatPOMP}) model together with a uni- or multi-variate time series on a collection of units.
Users will typically develop a POMP model for a single unit before embarking on a coupled SpatPOMP analysis.
Consequently, we assume some familiarity with \pkg{pomp} and its description by King, Nguyen and Ionides (2016).
The \code{spatPomp} class inherits from \code{pomp} with the additional unit structure being a defining feature of the resulting models and inference algorithms.
}
