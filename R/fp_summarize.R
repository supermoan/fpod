#' Calculates minute-resolution summaries of clicks
#'
#' @param x data.table where each row is a click, as the "clicks" element in
#'   the list object returned by [fp_read()]. Each row must minimally have a
#'   POSIXct column `time`. The return value of [fp_read()] is also accepted with a warning,
#'   provided that the clicks data.table is present .
#'
#' @param fpod_compat logical. If TRUE (the default), on-time follows the CPOD/FPOD
#'   official app: for CP3 files, every minute from the first click in `x` onwards
#'   counts as on, whatever the pod's tilt. Because `x` is usually filtered,
#'   this depends on the filter, as it does in the app. If FALSE, only minutes
#'   where the pod was probably logging (`env$pod_on` from [fp_read()]) count
#'   as on. That excludes minutes where the tilt exceeded the pod's switch
#'   angle, which the app counts as on once it has seen a click. For FP3
#'   files, both settings give the same result.
#'
#' @return A data.table with three or four columns:
#' * time: POSIXct timestamp of the start of the 1-minute time chunk, in YYYY-mm-dd HH:MM format
#' * dpm: detection-positive-minutes, 1 if at least one click is registered during the time chunk; 0 otherwise.
#' * bpm: buzz-positive-minutes, 1 if at least one feeding buzz is registered during the time chunk, 0 otherwise.
#' Note that bpm is only available if there is a 'buzz' column in the clicks data.table, e.g.
#' from first calling [fp_find_buzzes()]
#'
#' @seealso [fp_find_buzzes()], [lubridate::floor_date()]
#'
#' @examples
#' # first read some FPOD data
#' fn <- fp_example("gullars_period1.FP3")
#' dat <- fp_read(fn)
#'
#' # extract porpoise clicks of quality Hi and Mod
#' nbhf <- dat$clicks[species == "NBHF" & quality_level >= 2]
#'
#' # get a simple summary, with timestamp, degC and dpm.
#' dpm <- fp_summarize(nbhf)
#'
#' # If we also wanted buzz-positive-minutes, we could do this first.
#' nbhf$buzz <- fp_find_buzzes(nbhf, method = "clicks")
#'
#' # This time, when we call fp_summarize, it should detect that there's a
#' # buzz column, and automatically calculate feeding-positive-minutes as well.
#' dpm <- fp_summarize(nbhf)
#'
#' # Once we have DPMs, we can easily aggregate these into coarser time chunks
#' dpm_per_hour <- dpm[, .(dpm = sum(dpm)),
#'     .(date = as.POSIXct(trunc(time, unit = "hours")))] # per hour
#' dpm_per_day <- dpm[, .(dpm = sum(dpm)),
#'     .(date = as.Date(time))] # per day
#' dpm_per_month <- dpm[, .(dpm = sum(dpm)),
#'     .(date = as.POSIXct(trunc(time, unit = "months")))] # per month
#'
#' @import data.table
#' @export
fp_summarize <- function(x, fpod_compat = TRUE) {

    if (inherits(x, "list") && "clicks" %in% names(x) && "time" %in% colnames(x$clicks)) {
        warning("x is a list; expected data.table, but a clicks data.table was
        auto-detected and will be used. In future, consider using the more explicit
        fp_summarize(", substitute(x), "$clicks) to disable this warning")
        x <- x$clicks
    }

    if (!all(c("start", "on") %in% names(attributes(x)))) {
        stop("x lacks attributes needed to infer on-time")
    }

    if (!inherits(attr(x, "start"), "POSIXct") || !inherits(attr(x, "on"), "integer")) {
        stop("x has malformed attributes; can't infer on-time")
    }

    if (length(unique(x$pod)) > 1L) {
        warning("not all pod values are identical; only the first one will be used")
    }

    has_buzz <- "buzz" %in% colnames(x) && inherits(x$buzz, "integer")
    if (!has_buzz) {
        x$buzz <- NA_integer_
    }
    on_minutes <- attr(x, "on") # fallback if minutes attribute has been lost

    if (isTRUE(fpod_compat) && nrow(x) > 0L && !is.null(attr(x, "minutes"))) {
        # FPOD app compatibility: once the app has read a click, it no longer
        # checks the pod's tilt, so every later minute counts as on.
        all_minutes <- attr(x, "minutes")
        on_minutes <- sort(union(on_minutes,
                                 all_minutes[all_minutes >= min(x$minute)]))
    }
    dat_full <- data.table(pod = x$pod[1],
                           time = attr(x, "start") + on_minutes*60,
                           dpm = 0L, # detection positive minutes
                           bpm = if (has_buzz) 0L else NA_integer_) # buzz positive minutes

    if (nrow(x) > 0L) {
        dat <- x[, list(dpm = as.integer(.N>0L), # detection positive mins
                        bpm = as.integer(sum(buzz)>0L)), # buzz positive mins
                 list(time = as.POSIXct(trunc(time, unit = "mins")))]
        dat_full[dat, on = "time", c("dpm", "bpm") := list(i.dpm, i.bpm)]
    }

    dat_full
}


