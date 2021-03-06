% Generated by roxygen2: do not edit by hand
% Please edit documentation in R/hijacks.R
\name{hijack}
\alias{hijack}
\title{Hijack a function to change default parameters}
\usage{
hijack(FUN, ...)
}
\description{
Create copy function with defaults set to something more useful. Taken from r-bloggers somewhere
}
\examples{
.data.frame <- hijack(data.frame, stringsAsFactors = FALSE)
dat <- .data.frame(x1 = 1:3, x2 = c("a", "b", "c"))
str(dat)  # yay! strings are character

}
