##' Ensemble Kalman filters
##'
##' A function to perform filtering using the ensemble Kalman filter of Evensen, G. (1994)
##'
##' @name senkf
##' @rdname senkf
##' @include spatPomp_class.R spatPomp.R
##' @aliases senkf  senkf,ANY-method senkf,missing-method
##' @family particle filtering methods
##' @family \pkg{spatPomp} parameter estimation methods
##'
##' @inheritParams spatPomp
##' @param Np the number of particles to use.
##' @param h function returning the expected value of the observation given the
##' state.
##' @param C matrix converting state vector into expected value of the
##' observation.
##' @param R matrix; variance of the measurement noise.
##'
##' @return
##' An object of class \sQuote{kalmand_spatPomp}.
##'
##' @references
##' Evensen, G. (1994) Sequential data assimilation with a
##' nonlinear quasi-geostrophic model using Monte Carlo methods to forecast
##' error statistics Journal of Geophysical Research: Oceans 99:10143--10162
##'
##' Evensen, G. (2009) Data assimilation: the ensemble Kalman filter
##' Springer-Verlag.
##'
##' Anderson, J. L. (2001) An Ensemble Adjustment Kalman Filter for Data
##' Assimilation Monthly Weather Review 129:2884--2903
NULL

setClass(
  "kalmand_spatPomp",
  contains="kalmand_pomp",
  slots=c(
    units = 'character',
    unit_statenames = 'character',
    obstypes = 'character',
    unit_dmeasure = 'pomp_fun',
    unit_rmeasure = 'pomp_fun',
    unit_emeasure = 'pomp_fun',
    unit_vmeasure = 'pomp_fun',
    unit_mmeasure = 'pomp_fun'
  ),
  prototype=prototype(
    unit_dmeasure = pomp:::pomp_fun(slotname="unit_dmeasure"),
    unit_rmeasure = pomp:::pomp_fun(slotname="unit_rmeasure"),
    unit_emeasure = pomp:::pomp_fun(slotname="unit_emeasure"),
    unit_vmeasure = pomp:::pomp_fun(slotname="unit_vmeasure"),
    unit_mmeasure = pomp:::pomp_fun(slotname="unit_mmeasure")
  )
)

setGeneric(
  "senkf",
  function (data, ...)
    standardGeneric("senkf")
)


setMethod(
  "senkf",
  signature=signature(data="missing"),
  definition=function (...) {
    pomp:::reqd_arg("senkf","data")
  }
)

setMethod(
  "senkf",
  signature=signature(data="ANY"),
  definition=function (data, ...) {
    undef_method("senkf",data)
  }
)

## ENSEMBLE KALMAN FILTER (ENKF)

## Ensemble: $X_t\in \mathbb{R}^{m\times q}$
## Prediction mean: $M_t=\langle X \rangle$
## Prediction variance: $V_t=\langle\langle X \rangle\rangle$
## Forecast: $Y_t=h(X_t)$
## Forecast mean: $N_t=\langle Y \rangle$.
## Forecast variance: $S_t=\langle\langle Y \rangle\rangle$
## State/forecast covariance: $W_t=\langle\langle X,Y\rangle\rangle$
## Kalman gain: $K_t = W_t\,S_t^{-1}$
## New observation: $y_t\in \mathbb{R}^{n\times 1}$
## Updated ensemble: $X^u_{t}=X_t + K_t\,(O_t - Y_t)$
## Filter mean: $m_t=\langle X^u_t \rangle = \frac{1}{q} \sum\limits_{i=1}^q x^{u_i}_t$

##' @name senkf-spatPomp
##' @aliases senkf,spatPomp-method
##' @rdname senkf
##' @export
setMethod(
  "senkf",
  signature=signature(data="spatPomp"),
  function (data,
    Np, h, R,
    ..., verbose = getOption("verbose", FALSE)) {
    tryCatch(
      kp <- pomp:::enkf.internal(
        data,
        Np=Np,
        h=h,
        R=R,
        ...,
        verbose=verbose
      ),
      error = function (e) pomp:::pStop("senkf",conditionMessage(e))
    )
    new("kalmand_spatPomp", kp,
        unit_rmeasure = data@unit_rmeasure,
        unit_dmeasure = data@unit_dmeasure,
        unit_emeasure = data@unit_emeasure,
        unit_vmeasure = data@unit_vmeasure,
        unit_mmeasure = data@unit_mmeasure,
        units=data@units,
        unit_statenames=data@unit_statenames,
        obstypes = data@obstypes)

  }
)
