#' Finds harbor porpoise feeding buzzes
#'
#' This function uses one of two methods to classify NBHF clicks into one of
#' two classes: feeding buzz or non feeding buzz.
#'
#' @param x a data.table where each row is a click, as the "clicks" element in
#'  the list object returned by [fp_read()]. Each row must minimally have a
#'  POSIXct column `time`, with nanosecond precision.
#' @param method the method to use to find feeding buzzes. See details.
#' @param ... Additional arguments passed to specific methods, when relevant.
#' For method="threshold", you can pass `threshold=10` to define the maximum
#' ICI for a buzz (with values interpreted in units of milliseconds)
#'
#' @details
#' Note that the so-called "feeding buzzes" are usually considered to represent
#' a combination of feeding buzzes and social calls. Even so, the classifications
#' resulting from all of these methods are commonly used as a proxy of foraging
#' activity.
#'
#' The available methods are:
#' * `clicks` or `pirotta1` method: any inter-click-interval (ICI) less than 20
#' milliseconds is considered a NBHF feeding buzz.
#' * `trains` or `pirotta2` method: buzzes are identified using a mixture Gaussian
#' model, with the number of components k=3. All clicks associated with the first
#' component are considered a NBHF feeding buzz. This method requires the package
#' `mixtools` to work. Note that different implementations of this method sometimes
#' use different units for the ICIs (e.g. decimal minutes or milliseconds). The
#' choice of units doesn't necessarily change the estimates, but it may affect
#' the numerical stability of the computation and lead to false/early/non-optimal
#' convergence. Therefore, the `fpod` package uses units of milliseconds.
#' * `sbfi` or `sbfi1` method: the Search Buzz Foraging Identification method
#' described in Aofui et al 2026. Requires 3 or more consecutive ICIs between
#' 1.25 - 6.65 ms, preceded in the same minute by a search/approach click
#' (< 200 clicks/s). Minute groups are pre-defined based on the FPOD starting time.
#'
#' * `sbfi2` method: as `sbfi`, but with a small refinement. Rather than restrict
#' the identification of search-buzzes to pre-defined minute groups, this method
#' uses an adaptive minute window. It first identifies clusters of buzzes, and then
#' identifies the subset of those clusters that are preceded by a search click
#' within 60s (disregarding minute chunks). This method is more resilient to
#' edge-cases, where you have a search-buzz sequence on either side of a minute
#' (that would otherwise be missed with method="sbfi"). This affects absolute
#' buzz numbers more than derived estimates such as buzz-positive-minutes. The
#' latter isn't necessarily very different between these two variations of the
#' SBFI. Note that buzzes for the edge cases always get assigned to the later
#' minute.
#'
#' * `threshold` method: any inter-click-interval (ICI) less than the defined
#' threshold is considered a NBHF feeding buzz. The threshold must be
#' specified in milliseconds.
#'
#' @returns An integer vector of the same length as `nrow(x)`, where the values
#' indicate that that click (or a sequence of clicks) can be considered a feeding
#' buzz (value = 1) or not (value = 0).
#'
#' @references Aoufi, S., Rumes, B., Vanaverbeke, J., Degraer, S., & Debusschere,
#' E. (2026). A Novel Method to Infer Harbor Porpoise Foraging Behavior From
#' Acoustic Data: A Comparative Assessment Against Established Techniques.
#' Marine Mammal Science, 42(4), e70292. https://doi.org/10.1111/mms.70292
#'
#' Pirotta, E., Thompson, P.M., Miller, P.I., Brookes, K.L., Cheney,
#' B., Barton, T.R., Graham, I.M. and Lusseau, D. (2014), Scale-dependent foraging
#' ecology of a marine top predator modelled using passive acoustic data. Funct
#' Ecol, 28: 206-217. https://doi.org/10.1111/1365-2435.12146
#'
#'
#'
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
#' nbhf$pirotta1 <- fp_find_buzzes(nbhf, method = "clicks")
#'
#' # using method="clicks" is the equivalent of this:
#' nbhf$threshold20ms <- fp_find_buzzes(nbhf, method = "threshold", threshold = 20)
#'
#' # using the gaussian mixture model approach is just as easy:
#' nbhf$pirotta2 <- fp_find_buzzes(nbhf, method = "pirotta2")
#'
#' # or we can use one of two variations of the SBFI
#' nbhf$sbfi <- fp_find_buzzes(nbhf, method = "sbfi")
#' nbhf$sbfi2 <- fp_find_buzzes(nbhf, method = "sbfi2")
#'
#' # we can easily compare all of these methods in terms of absolute buzz
#' # numbers and positive buzz minutes (BPMs)
#'
#' # first extract only the cols that we need to do this
#' buzz <- nbhf[, .(minute, pirotta1, threshold20ms, pirotta2, sbfi, sbfi2)]
#' # define BPMs
#' bpm <- buzz[, lapply(.SD, function(x) any(x>0)), by = minute][,-1]
#'
#' # finally, print comparative table
#' data.frame(
#'     method = names(bpm),
#'     tot_clicks = nrow(nbhf),
#'     tot_buzzes = as.integer(buzz[,lapply(.SD,sum)][,-1]),
#'     bpm = as.integer(bpm[,lapply(.SD,sum)])
#' )
#'
#' @import data.table
#' @export

fp_find_buzzes <- function(x, method = "clicks", ...) {

    params <- list(...)

    if (!"time" %in% colnames(x) || !inherits(x$time, "POSIXct")) {
        stop("x must be a data.table/data.frame with click timestamps in a POSIXct column `time`")
    }

    # we need at least two clicks to do anything
    if (length(x$time) <= 1) {
        return(NULL)
    }

    # ICIs in units of milliseconds
    ici_ms <- c(NA_real_, as.numeric(diff(x$time, units = "secs")))*10^3

    buzz <- rep(0L, length(ici_ms))

    # SBFI (search buzz foraging identification)
    # two variations
    if (method %in% c("sbfi", "sbfi1", "sbfi2")) {

        sbfi <- data.table(id = seq_along(ici_ms),
                           time = x$time,
                           search = as.integer(ici_ms > 5),
                           buzz = as.integer(ici_ms > 1.25 & ici_ms < 6.65),
                           group = floor(as.numeric(x$time) / 60))
        sbfi[, group := group-min(group)+1]
        sbfi[, buzz_group := rleid(buzz)]
        sbfi[, buzz_cumsum := fifelse(!is.na(buzz) & buzz == 1, cumsum(buzz), 0L), buzz_group]
        sbfi[, is_buzz := 0L]

        buzz_start <- sbfi[buzz_cumsum == 3, .(buzz_id = id - 2L, buzz_group, group_buzz = group, time_buzz = time)]
        buzz_start[, c("time_lwr", "time_upr") := list(time_buzz - 60, time_buzz)]
        searches <- sbfi[search == 1, .(time_search = time, search_id = id, group_search = group)]
        matches <- searches[buzz_start, on = .(time_search >= time_lwr, time_search <= time_upr), nomatch = NULL]

        if (method %in% c("sbfi", "sbfi1")) {
            matches <- matches[group_search == group_buzz & search_id < buzz_id]
            valid_pairs <- unique(matches[, .(buzz_group, group = group_buzz)])
            sbfi[valid_pairs, on = .(buzz_group, group), is_buzz := 1L]

        } else {
            # adaptive window (not restricted to look inside pre-defined minutes)
            sbfi[buzz_group %in% unique(matches$buzz_group), is_buzz := 1L]

        }

        return(sbfi$is_buzz)
    }

    if (method == "threshold") {
        if ("threshold" %in% names(params)) {
            threshold <- params[["threshold"]]
        } else {
            stop("when using method=\"threshold\", threshold must be defined")
        }
        if (length(threshold) != 1L || !is.numeric(threshold) || threshold <= 0) {
            stop("threshold must be a single positive number")
        }
        buzz[which(ici_ms < threshold)] <- 1L
        return(buzz)
    }
    if (method %in% c("clicks", "pirotta1")) {

        buzz[which(ici_ms < 20)] <- 1L
        return(buzz)

    } else if (method %in% c("trains", "pirotta2")) {

        if (!requireNamespace("mixtools", quietly = TRUE)) {
            stop("Package \"mixtools\" must be installed to use method=\"trains\"")
        }

        sorted <- !is.unsorted(x$time)

        logICI_ms <- suppressWarnings(log(ici_ms))
        valid <- which(!is.na(logICI_ms) & !is.infinite(logICI_ms))

        if (length(valid) == 0) {
            stop("all inter-click-intervals are NA - nothing to do!")
        }

        if (sorted == FALSE) {
            warning("clicks are not ordered chronologically, check results carefully")
        }

        fit <- mixtools::normalmixEM(logICI_ms[valid], k = 3)
        # mu estimates are not necessarily in order from lowest to biggest
        buzz_component <- which.min(fit$mu)
        # assign most likely component to each click
        buzz[valid] <- apply(fit$posterior, 1, which.max)
        # mark buzzes
        buzz[valid] <- as.integer(buzz[valid] == buzz_component)
        return(buzz)

    }

    stop("method not recognized, see ?fp_find_buzzes for available methods")

}


