
#~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~#
# BOOTSTRAPPING                                                                                         ####

#' Get bootstrap distribution of a statistic over a set of values
#' 
#' @param x Vector or array of values
#' @param nsamp Number of bootstrap samples to produce. Default is 10000.
#' @param fn Statistic to calculate for each bootstrap sample. Default is mean.
#' 
#' @return nsamp-length vector of bootstrapped statistics 
#' 
#' @export
#'  
bootstrap <- function(x, nsamp = 10000, fn = mean) {
    n <- length(c(x))
    samp <- array(sample(1:n, n * nsamp, replace = T), dim = c(n,nsamp))
    
    apply(samp, 2, function(ind) fn(x[ind]))
}



#' Check where target value falls within bootstrap sample
#' 
#' @param boot.samp Vector of bootstrapped statistic, as returned by \link{\code{bootstrap}}
#' @param target Target value. Default is 0.
#' @param q1 Lower probability bound. Default is 0.025.
#' @param q2 Upper probability bound. Default is 0.975.
#' 
#' @return Value: either 0 (target in lower tail), 1 (target not significant), or 2 (target in upper tail)
#' 
#' @export
#' 
boot.sig <- function(boot.samp, target = 0, q1 = 0.025, q2 = 0.975) {
    findInterval(0, quantile(boot.samp, c(q1, q2)))
}


#' Identify whether points fall within an ellipse
#'
#' @param px Points to be tested
#' @param mu Centre of ellipse
#' @param Sigma Covariance matrix describing ellipse
#' @param p Define proportion of density to include
#'
#' @export
#'
px.in.ellipse <- function(px, mu, Sigma, p = 0.95) {

    # transform event space onto ellipsoid space
    # from https://github.com/AndrewLJackson/SIBER/blob/master/R/pointsToEllipsoid.R

    eig <- eigen(Sigma)                      # eigen values and vectors of the covariance matrix
    SigSqrt = eig$vectors %*% diag(sqrt(eig$values)) %*% t(eig$vectors)      # inverse of sigma
    Z <- t(apply(px, 1, function(x) solve(SigSqrt, x - mu)))        # transform the points

    # from https://github.com/AndrewLJackson/SIBER/blob/master/R/ellipseInOut.R
    r <- stats::qchisq(p, df = ncol(Z))         # Define size of ellipse to include
    inside <- rowSums(Z ^ 2) < r
    cbind(px, "inside" = inside)
}



#' Check matrix equivalence
#'
#' Confirm whether two matrix equations produce identical output
#'
#' @param expr1 First matrix equation; either a string using A,B,C,D or a formula using matrices in the global environment
#' @param expr2 Second matrix equation; either a string using A,B,C,D or a formula using matrices in the global environment
#' @param dp Number of significant figures to check result to; default is 12.
#' @param seed Integer: seed used to generate random matrices
#'
#' @export
#'
matcheck <- function(expr1, expr2, dp = 12, seed = 1) {

  A <- B <- C <- D <- array(NA, dim = c(3,3))
  I <- diag(3)

  set.seed(seed)
  A[upper.tri(A)] <- A[lower.tri(A)] <- runif(3,0,2)
  diag(A) <- rnorm(3,2,1)

  B[upper.tri(B)] <- B[lower.tri(B)] <- runif(3,0,2)
  diag(B) <- rnorm(3,2,1)

  C[upper.tri(C)] <- C[lower.tri(C)] <- runif(3,0,2)
  diag(C) <- rnorm(3,2,1)

  D[upper.tri(D)] <- D[lower.tri(D)] <- runif(3,0,2)
  diag(D) <- rnorm(3,2,1)

  ev1 <- eval(parse(text = expr1))
  ev2 <- eval(parse(text = expr2))

  all(signif(ev1, dp) == signif(ev2, dp))
}



#' Check equivalence of two objects to a certain DP
#'
#' @export
chk <- function(o1, o2, dp = 9) {
  all(round(c(o1), dp) == round(c(o2), dp))
}



#' Parameters of mixture of Gaussian distributions
#' 
#' @export
#' 
mixt.pars <- function(mu.list, sig.list, weights) {
    
    M <- length(mu.list)
    if(missing(weights)) weights <- rep(1/M, M)
    
    mu.bar <- colSums(sweep(abind(mu.list, along = 0), 1, weights, "*"))
    
    E.var <- apply(sweep(abind(sig.list, along = 0), 1, weights, "*"), 2:3, sum)
    V.exp <- apply(sweep(aaply(sweep(abind(mu.list, along = 0), 2, mu.bar, "-"), 1,
                               function(mu.diff) mu.diff %*% t(mu.diff)), 1, weights, "*"), 2:3, sum)
    return(list("mean" = mu.bar, "var" = E.var + V.exp))
} 




#' Gamma parameters given specified mean/mode and variance
#' 
#' @param mean Mean of Gamma distribution. Only used if mode is not provided.
#' @param mode Mode of Gamma distribution.
#' @param var Variance of Gamma distribution.
#' 
#' @return List containing shape and rate parameters.
#' 
#' @export
#' 
gamm.pars <- function(mode, var, mean) {
    
    if(!missing(mode)) {
        r <- (mode + sqrt(mode^2 + 4*var)) / (2 * var)
        return(list("shape" = 1 + (mode * r), "rate" = r))
    } else {
        return(list("shape" = mean^2 / var, "rate" = mean/var))
    }
}


#' Update ratty weight graphs with latest data in Google Sheets
#' 
#' @export
#' 
ratty.weights <- function() {
    
    library(googledrive); library(tidyverse); library(httpuv); library(imputeTS); library(readxl)
    
    org.dir <- getwd()
    setwd("~/Documents/Ratties")
    
    options("httr_oob_default" = TRUE)
    
    # download data from Google Drive
    drive_download(as_id("1gzPe8RG2-UfNFyzBuK48J-uvB08PEfs78GKTUMT5QEA"), verbose = F, overwrite = T)
    
    rw <- read_xlsx("Ratty-weights.xlsx")
    rw$Date <- as.Date(rw$Date)
    
    first.q <- as.Date(cut(min(rw$Date), "quarter"))
    next.q <- as.Date(cut(as.Date(cut(Sys.Date(), "quarter")) + 100, "quarter"))
    
    # interpolate missing data
    rw.imp <- rw
    invisible(sapply(colnames(rw.imp[,2:(ncol(rw)-1)]), function(r) {
        w <- unlist(rw.imp[,r])
        w.min <- min(which(!is.na(w))); w.max <- max(which(!is.na(w)))
        rw.imp[w.min:w.max,r] <<- na.interpolation(w[w.min:w.max])
    }))
    
    # plot weights with interpolation
    #matplot(rw$Date, rw.imp[,2:(ncol(rw.imp)-1)], type = "l", lty = 2, xaxt = "n",
    #        xlab = "Date", ylab = "Weight (g)", las = 2)
    #axis.Date(1, at=seq(first.q, next.q, by="3 mon"), format="%b-%y")
    #abline(h = 0:7*100, v = seq(first.q, next.q, by="1 mon"), col = transp("grey"))
    #matplot(rw$Date, rw[,2:(ncol(rw.imp)-1)], type = "o", lty = 1, pch = 20, cex = 0.5, add = T)
    
    
    # convert dates to ages
    rw.age <- sapply(colnames(rw[,2:(ncol(rw)-1)]), function(r) {
        
        # get weights during lifespan
        w <- rw[,c("Date", r)]
        w <- w[min(which(!is.na(w[,2]))) : max(which(!is.na(w[,2]))),]
        
        return(data.frame("Age" = as.integer(w$Date - min(w$Date)), w[,2]))
    }, simplify = F) %>% reduce(full_join, by = "Age")
    rw.age <- rw.age[order(rw.age$Age),]
    
    age.spl <- rw.age
    invisible(sapply(colnames(age.spl[-1]), function(r) {
        w <- unlist(age.spl[,r])
        w.min <- min(which(!is.na(w))); w.max <- max(which(!is.na(w)))
        age.spl[w.min:w.max,r] <<- na.interpolation(w[w.min:w.max])
    }))
    
    # TBC - upload images to google drive
    r.cols <- c("navyblue", "blue2", "tomato", "red3", "chartreuse3", "forestgreen")
    
    pdf("./wplot.pdf"); {
        matplot(rw.imp$Date, rw.imp[,2:(ncol(rw)-1)], type = "o", lty = 1, xaxt = "n",  pch = 20, cex = 0.5,
                xlab = "Date", ylab = "Weight (g)", las = 2, col = transp(r.cols, 0.3))
        matplot(rw$Date, rw[,2:(ncol(rw)-1)], type = "o", lty = 1, pch = 20, cex = 0.5, col = r.cols, add = T)
        axis.Date(1, at=seq(first.q, next.q, by="3 mon"), format="%b-%y")
        abline(h = 0:7*100, v = seq(first.q, next.q, by="1 mon"), col = transp("grey"))
        legend("bottom", legend = colnames(rw)[2:(ncol(rw)-1)], col = r.cols, lty = 1, pch = 20, pt.cex = 0.5,
               bg = "white")
    }; dev.off()
    
    pdf("./aplot.pdf"); {
        matplot(age.spl$Age, age.spl[,-1], type = "l", lty = 1, pch = 4, cex = 0.5, xlab = "Age (~months)",
                ylab = "Weight (g)", xaxt = "n", las = 2, col = transp(r.cols, 0.3))
        matplot(rw.age$Age, rw.age[,-1], type = "o", lty = 1, pch = 20, cex = 0.5, add = T, col = r.cols)
        abline(h = (0:7) * 100, v = seq(0:36)*30, col = transp("grey"), lty = 1)
        abline(v =  seq(0, 36, 12)*30, col = transp("dimgrey"), lty = 2)
        axis(1, at = seq(0,max(rw.age$Age) + 90,90), label = seq(0,max(rw.age$Age) + 90,90) / 30)
        
        legend("bottomright", legend = colnames(rw)[2:(ncol(rw)-1)], col = r.cols, lty = 1, pch = 20, pt.cex = 0.5,
               bg = "white")
    }; dev.off()
    
    # upload plots to Google drive
    drive_update(as_id("1W_7mzlnYKlNFeEw5PLs0_SB2mJGRGcOC"), media = "aplot.pdf")
    drive_update(as_id("17dR1Ot_n61KwxFr9MKxEr1Ci53ZgY434"), media = "wplot.pdf")
    
    setwd(org.dir)
}