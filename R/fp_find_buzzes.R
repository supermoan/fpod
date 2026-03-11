#' Finds harbor porpoise feeding buzzes
#'
#' This function uses one of two methods to classify NBHF clicks into one of
#' two classes: feeding buzz or non feeding buzz.
#'
#' @param x a data.table where each row is a click, as the "clicks" element in
#' the list object returned by [fp_read()]. Each row must minimally have a
#' POSIXct column `time`, with nanosecond precision.
#' @param method the method to use to find feeding buzzes - "clicks" or "trains". See details.
#'
#' @details
#' Note that the so-called "feeding buzzes" are usually considered to represent
#' a combination of feeding buzzes and social calls. Even so, the classifications
#' resulting from both of these methods are commonly used as a proxy of foraging
#' activity.
#'
#' The two available methods are:
#' * `clicks` method: any inter-click-interval (ICI) less than 20 milliseconds
#' is considered a NBHF feeding buzz.
#' * `trains` method: buzzes are identified using a mixture Gaussian model, with
#' the number of components k=3. All clicks associated with the first component
#' are considered a NBHF feeding buzz. This method requires the package mixtools
#' to work.
#'
#' @returns An integer vector of the same length as `nrow(x)`, where the values
#' indicate that that click can be considered a feeding buzz (value = 1) or not (value = 0).
#'
#' @references Pirotta, E., Thompson, P.M., Miller, P.I., Brookes, K.L., Cheney,
#' B., Barton, T.R., Graham, I.M. and Lusseau, D. (2014), Scale-dependent foraging
#' ecology of a marine top predator modelled using passive acoustic data. Funct
#' Ecol, 28: 206-217. https://doi.org/10.1111/1365-2435.12146
#'
#' @examples
#' # first read some FPOD data
#' fn <- fp_example("gullars_period1.FP3")
#' dat <- fp_read(fn)
#'
#' # extract porpoise clicks of quality Hi and Mod
#' nbhf <- dat$clicks[species == "NBHF" & quality_level >= 2]
#'
#' # then add a 'feeding buzz' column to the clicks data.table
#' nbhf$buzz <- fp_find_buzzes(nbhf, method = "clicks")
#'
#' @import data.table
#' @export

fp_find_buzzes <- function(x, method = "clicks") {
    ici <- c(NA_real_, as.numeric(diff(x$time, units = "mins")))
    buzz <- rep(0L, length(ici))

    if (method == "clicks") {
        buzz[which(ici < 0.33e-3)] <- 1L # this corresponds to 20 ms

    } else if (method == "trains") {

        if (!requireNamespace("mixtools", quietly = TRUE)) {
            stop("Package \"mixtools\" must be installed to use method=\"trains\"")
        }

        # check order of timestamps and issue a warning if they seem off
        ot <- order(x$time)
        if (any(ot != seq(1, length(ot)))) {
            warning("clicks are not ordered chronologically, check results carefully")
        }

        logICI <- log(ici)
        valid <- which(!is.na(logICI) & !is.infinite(logICI))
        fit <- mixtools::normalmixEM(logICI[valid], k = 3)
        buzz[valid] <- apply(fit$posterior, 1, which.max)
        buzz[valid] <- as.integer(buzz[valid] == 1)

    } else {
        stop("method must be either 'clicks' or 'trains'")
    }

    buzz
}
