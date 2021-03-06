% Generated by roxygen2: do not edit by hand
% Please edit documentation in R/fpca_face.R
\name{fpca_face}
\alias{fpca_face}
\title{Functional principal component analysis with fast covariance estimation}
\usage{
fpca_face(
  data = NULL,
  Y.pred = NULL,
  argvals = NULL,
  pve = 0.99,
  npc = NULL,
  center = TRUE,
  knots = 35,
  p = 3,
  m = 2,
  lambda = NULL,
  alpha = 1,
  search.grid = TRUE,
  search.length = 100,
  method = "L-BFGS-B",
  lower = -20,
  upper = 20,
  control = NULL
)
}
\arguments{
\item{data}{a \code{tf} vector containing the functions to decompose using FPCA.
Alternatively, a dataframe with arguments arg, value, id. In either case, data
must be observed over a regular grid.}

\item{Y.pred}{if desired, a matrix of functions to be approximated using
the FPC decomposition.}

\item{argvals}{numeric; function argument.}

\item{pve}{proportion of variance explained: used to choose the number of
principal components.}

\item{npc}{how many smooth SVs to try to extract, if \code{NA} (the
default) the hard thresholding rule of Gavish and Donoho (2014) is used (see
Details, References).}

\item{center}{logical; center \code{data} so that its column-means are 0? Defaults to
\code{TRUE}}

\item{knots}{number of knots to use or the vectors of knots; defaults to 35}

\item{p}{integer; the degree of B-splines functions to use}

\item{m}{integer; the order of difference penalty to use}

\item{lambda}{smoothing parameter; if not specified smoothing parameter is
chosen using \code{\link[stats:optim]{stats::optim()}} or a grid search}

\item{alpha}{numeric; tuning parameter for GCV; see parameter \code{gamma}
in \code{\link[mgcv:gam]{mgcv::gam()}}}

\item{search.grid}{logical; should a grid search be used to find \code{lambda}?
Otherwise, \code{\link[stats:optim]{stats::optim()}} is used}

\item{search.length}{integer; length of grid to use for grid search for
\code{lambda}; ignored if \code{search.grid} is \code{FALSE}}

\item{method}{method to use; see \code{\link[stats:optim]{stats::optim()}}}

\item{lower}{see \code{\link[stats:optim]{stats::optim()}}}

\item{upper}{see \code{\link[stats:optim]{stats::optim()}}}

\item{control}{see \code{\link[stats:optim]{stats::optim()}}}
}
\value{
A list with components
\enumerate{
\item \code{Yhat} - If \code{Y.pred} is specified, the smooth version of
\code{Y.pred}.   Otherwise, if \code{Y.pred=NULL}, the smooth version of \code{data}.
\item \code{scores} - matrix of scores
\item \code{mu} - mean function
\item \code{npc} - number of principal components
\item \code{efunctions} - matrix of eigenvectors
\item \code{evalues} - vector of eigenvalues
}
}
\description{
A fast implementation of the sandwich smoother (Xiao et al., 2013)
for covariance matrix smoothing. Pooled generalized cross validation
at the data level is used for selecting the smoothing parameter.
}
\references{
Xiao, L., Li, Y., and Ruppert, D. (2013).
Fast bivariate \emph{P}-splines: the sandwich smoother,
\emph{Journal of the Royal Statistical Society: Series B}, 75(3), 577-599.

Xiao, L., Ruppert, D., Zipunnikov, V., and Crainiceanu, C. (2016).
Fast covariance estimation for high-dimensional functional data.
\emph{Statistics and Computing}, 26, 409-421.
DOI: 10.1007/s11222-014-9485-x.
}
\author{
Luo Xiao
}
