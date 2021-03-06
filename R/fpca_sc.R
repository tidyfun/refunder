##' Functional principal components analysis by smoothed covariance
##'
##' Decomposes functional observations using functional principal components
##' analysis. A mixed model framework is used to estimate scores and obtain
##' variance estimates.
##'
##' This function computes a FPC decomposition for a set of observed curves,
##' which may be sparsely observed and/or measured with error. A mixed model
##' framework is used to estimate curve-specific scores and variances.
##'
##' FPCA via kernel smoothing of the covariance function, with the diagonal
##' treated separately, was proposed in Staniswalis and Lee (1998) and much
##' extended by Yao et al. (2005), who introduced the 'PACE' method.
##' `fpca.sc` uses penalized splines to smooth the covariance function, as
##' developed by Di et al. (2009) and Goldsmith et al. (2013).
##'
##' @param data a `tf` vector containing the functions to decompose using FPCA.
##' Alternatively, a dataframe with arguments arg, value, id.
##' @param Y.pred if desired, a matrix of functions to be approximated using
##' the FPC decomposition.
##' @param argvals the argument values of the function evaluations in `data`,
#'  defaults to a equidistant grid from 0 to 1.
##' @param random.int If `TRUE`, the mean is estimated by
##' [gamm4::gamm4()] with random intercepts. If `FALSE` (the
##' default), the mean is estimated by [mgcv::gam()] treating all the
##' data as independent.
##' @param nbasis number of B-spline basis functions used for estimation of the
##' mean function and bivariate smoothing of the covariance surface.
##' @param pve proportion of variance explained: used to choose the number of
##' principal components.
##' @param npc prespecified value for the number of principal components (if
##' given, this overrides `pve`).
##' @param useSymm logical, indicating whether to smooth only the upper
##' triangular part of the naive covariance (when `cov.est.method==2`).
##' This can save computation time for large data sets, and allows for
##' covariance surfaces that are very peaked on the diagonal.
##' @param makePD logical: should positive definiteness be enforced for the
##' covariance surface estimate?
##' @param center logical: should an estimated mean function be subtracted from
##' `data`? Set to `FALSE` if you have already demeaned the data using
##' your favorite mean function estimate.
##' @param cov.est.method covariance estimation method. If set to `1`, a
##' one-step method that applies a bivariate smooth to the \eqn{y(s_1)y(s_2)}
##' values. This can be very slow. If set to `2` (the default), a two-step
##' method that obtains a naive covariance estimate which is then smoothed.
##' @param integration quadrature method for numerical integration; only
##' `'trapezoidal'` is currently supported.
##' @return An object of class `fpca` containing:
##' \item{Yhat}{FPC approximation (projection onto leading components)
##' of `data`.}\item{scores}{\eqn{n
##' \times npc} matrix of estimated FPC scores.} \item{mu}{estimated mean
##' function (or a vector of zeroes if `center==FALSE`).} \item{efunctions
##' }{\eqn{d \times npc} matrix of estimated eigenfunctions of the functional
##' covariance, i.e., the FPC basis functions.} \item{evalues}{estimated
##' eigenvalues of the covariance operator, i.e., variances of FPC scores.}
##' \item{npc }{number of FPCs: either the supplied `npc`, or the minimum
##' number of basis functions needed to explain proportion `pve` of the
##' variance in the observed curves.} \item{argvals}{argument values of
##' eigenfunction evaluations}
##' @author Jeff Goldsmith \email{jeff.goldsmith@@columbia.edu}, Sonja Greven
##' \email{sonja.greven@@stat.uni-muenchen.de}, Lan Huo
##' \email{Lan.Huo@@nyumc.org}, Lei Huang \email{huangracer@@gmail.com}, and
##' Philip Reiss \email{phil.reiss@@nyumc.org}
##' @references Di, C., Crainiceanu, C., Caffo, B., and Punjabi, N. (2009).
##' Multilevel functional principal component analysis. *Annals of Applied
##' Statistics*, 3, 458--488.
##'
##' Goldsmith, J., Greven, S., and Crainiceanu, C. (2013). Corrected confidence
##' bands for functional data using principal components. *Biometrics*,
##' 69(1), 41--51.
##'
##' Staniswalis, J. G., and Lee, J. J. (1998). Nonparametric regression
##' analysis of longitudinal data. *Journal of the American Statistical
##' Association*, 93, 1403--1418.
##'
##' Yao, F., Mueller, H.-G., and Wang, J.-L. (2005). Functional data analysis
##' for sparse longitudinal data. *Journal of the American Statistical
##' Association*, 100, 577--590.
##' @importFrom stats predict quantile weighted.mean
##' @importFrom Matrix nearPD Matrix t as.matrix
##' @importFrom mgcv gam predict.gam
##' @importFrom gamm4 gamm4
##' @export
fpca_sc <- function(data,  Y.pred = NULL, argvals = NULL, random.int = FALSE,
  nbasis = 10, pve = 0.99, npc = NULL,
  useSymm = FALSE, makePD = FALSE, center = TRUE, cov.est.method = 2, integration = "trapezoidal") {

  #data <- tidyfun:::df_2_mat(data) ## calls complete.cases on the data, only use this once fixed regular function
  data <- as.matrix(spread(as.data.frame(data), key = .data$arg, value = .data$value)[,-1])
  if (is.null(Y.pred))
    Y.pred = data
  D = NCOL(data)
  I = NROW(data)
  I.pred = NROW(Y.pred)

  if (is.null(argvals))
    argvals = seq(0, 1, length = D)

  d.vec = rep(argvals, each = I)
  id = rep(1:I, rep(D, I))

  if (center) {
    if (random.int) {
      ri_data <- data.frame(y = as.vector(data), d.vec = d.vec, id = factor(id))
      gam0 = gamm4(y ~ s(d.vec, k = nbasis), random = ~(1 | id), data = ri_data)$gam
      rm(ri_data)
    } else gam0 = gam(as.vector(data) ~ s(d.vec, k = nbasis))
    mu = predict(gam0, newdata = data.frame(d.vec = argvals))
    data.tilde = data - matrix(mu, I, D, byrow = TRUE)
  } else {
    data.tilde = data
    mu = rep(0, D)
  }

  if (cov.est.method == 2) {
    # smooth raw covariance estimate
    cov.sum = cov.count = cov.mean = matrix(0, D, D)
    for (i in 1:I) {
      obs.points = which(!is.na(data[i, ]))
      cov.count[obs.points, obs.points] = cov.count[obs.points, obs.points] +
        1
      cov.sum[obs.points, obs.points] = cov.sum[obs.points, obs.points] + tcrossprod(data.tilde[i,
        obs.points])
    }
    G.0 = ifelse(cov.count == 0, NA, cov.sum/cov.count)
    diag.G0 = diag(G.0)
    diag(G.0) = NA
    if (!useSymm) {
      row.vec = rep(argvals, each = D)
      col.vec = rep(argvals, D)
      npc.0 = matrix(predict(gam(as.vector(G.0) ~ te(row.vec, col.vec, k = nbasis),
        weights = as.vector(cov.count)), newdata = data.frame(row.vec = row.vec,
        col.vec = col.vec)), D, D)
      npc.0 = (npc.0 + t(npc.0))/2
    } else {
      use <- upper.tri(G.0, diag = TRUE)
      use[2, 1] <- use[ncol(G.0), ncol(G.0) - 1] <- TRUE
      usecov.count <- cov.count
      usecov.count[2, 1] <- usecov.count[ncol(G.0), ncol(G.0) - 1] <- 0
      usecov.count <- as.vector(usecov.count)[use]
      use <- as.vector(use)
      vG.0 <- as.vector(G.0)[use]
      row.vec <- rep(argvals, each = D)[use]
      col.vec <- rep(argvals, times = D)[use]
      mCov <- gam(vG.0 ~ te(row.vec, col.vec, k = nbasis), weights = usecov.count)
      npc.0 <- matrix(NA, D, D)
      spred <- rep(argvals, each = D)[upper.tri(npc.0, diag = TRUE)]
      tpred <- rep(argvals, times = D)[upper.tri(npc.0, diag = TRUE)]
      smVCov <- predict(mCov, newdata = data.frame(row.vec = spred, col.vec = tpred))
      npc.0[upper.tri(npc.0, diag = TRUE)] <- smVCov
      npc.0[lower.tri(npc.0)] <- t(npc.0)[lower.tri(npc.0)]
    }
  } else if (cov.est.method == 1) {
    # smooth y(s1)y(s2) values to obtain covariance estimate
    row.vec = col.vec = G.0.vec = c()
    cov.sum = cov.count = cov.mean = matrix(0, D, D)
    for (i in 1:I) {
      obs.points = which(!is.na(data[i, ]))
      temp = tcrossprod(data.tilde[i, obs.points])
      diag(temp) = NA
      row.vec = c(row.vec, rep(argvals[obs.points], each = length(obs.points)))
      col.vec = c(col.vec, rep(argvals[obs.points], length(obs.points)))
      G.0.vec = c(G.0.vec, as.vector(temp))
      # still need G.O raw to calculate to get the raw to get the diagonal
      cov.count[obs.points, obs.points] = cov.count[obs.points, obs.points] +
        1
      cov.sum[obs.points, obs.points] = cov.sum[obs.points, obs.points] + tcrossprod(data.tilde[i,
        obs.points])
    }
    row.vec.pred = rep(argvals, each = D)
    col.vec.pred = rep(argvals, D)
    npc.0 = matrix(predict(gam(G.0.vec ~ te(row.vec, col.vec, k = nbasis)), newdata = data.frame(row.vec = row.vec.pred,
      col.vec = col.vec.pred)), D, D)
    npc.0 = (npc.0 + t(npc.0))/2
    G.0 = ifelse(cov.count == 0, NA, cov.sum/cov.count)
    diag.G0 = diag(G.0)
  }

  if (makePD) {
    npc.0 <- {
      tmp <- Matrix::nearPD(npc.0, corr = FALSE, keepDiag = FALSE, do2eigen = TRUE,
        trace = TRUE)
      as.matrix(tmp$mat)
    }
  }
  ### numerical integration for calculation of eigenvalues (see Ramsay & Silverman,
  ### Chapter 8)
  w <- quadWeights(argvals, method = integration)
  Wsqrt <- diag(sqrt(w))
  Winvsqrt <- diag(1/(sqrt(w)))
  V <- Wsqrt %*% npc.0 %*% Wsqrt
  evalues = eigen(V, symmetric = TRUE, only.values = TRUE)$values
  ###
  evalues = replace(evalues, which(evalues <= 0), 0)
  npc = ifelse(is.null(npc), min(which(cumsum(evalues)/sum(evalues) > pve)), npc)
  efunctions = matrix(Winvsqrt %*% eigen(V, symmetric = TRUE)$vectors[, seq(len = npc)],
    nrow = D, ncol = npc)
  evalues = eigen(V, symmetric = TRUE, only.values = TRUE)$values[1:npc]  # use correct matrix for eigenvalue problem
  cov.hat = efunctions %*% tcrossprod(diag(evalues, nrow = npc, ncol = npc), efunctions)
  ### numerical integration for estimation of sigma2
  T.len <- argvals[D] - argvals[1]  # total interval length
  T1.min <- min(which(argvals >= argvals[1] + 0.25 * T.len))  # left bound of narrower interval T1
  T1.max <- max(which(argvals <= argvals[D] - 0.25 * T.len))  # right bound of narrower interval T1
  DIAG = (diag.G0 - diag(cov.hat))[T1.min:T1.max]  # function values
  w2 <- quadWeights(argvals[T1.min:T1.max], method = integration)
  sigma2 <- max(weighted.mean(DIAG, w = w2, na.rm = TRUE), 0)
  error_var <- sigma2

  ####
  D.inv = diag(1/evalues, nrow = npc, ncol = npc)
  Z = efunctions
  data.tilde = Y.pred - matrix(mu, I.pred, D, byrow = TRUE)
  Yhat = matrix(0, nrow = I.pred, ncol = D)
  rownames(Yhat) = rownames(Y.pred)
  colnames(Yhat) = colnames(Y.pred)
  scores = matrix(NA, nrow = I.pred, ncol = npc)
  for (i.subj in 1:I.pred) {
    obs.points = which(!is.na(Y.pred[i.subj, ]))
    if (sigma2 == 0 & length(obs.points) < npc)
      stop("Measurement error estimated to be zero and there are fewer observed points than PCs; scores cannot be estimated.")
    Zcur = matrix(Z[obs.points, ], nrow = length(obs.points), ncol = dim(Z)[2])
    ZtZ_sD.inv = solve(crossprod(Zcur) + sigma2 * D.inv)
    scores[i.subj, ] = ZtZ_sD.inv %*% t(Zcur) %*% (data.tilde[i.subj, obs.points])
    Yhat[i.subj, ] = t(as.matrix(mu)) + scores[i.subj, ] %*% t(efunctions)
  }

  ret.objects = c("mu", "efunctions", "scores", "npc", "evalues", "error_var")

  ret = lapply(1:length(ret.objects), function(u) get(ret.objects[u]))
  names(ret) = ret.objects
  class(ret) = "fpca"
  return(ret)
}
