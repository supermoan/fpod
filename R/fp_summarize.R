#' Calculates minute-resolution summaries of detections and other variables
#'
#' @param clicks data.table where each row is a click, as the "clicks" element in
#' the list object returned by [fp_read()]. Each row must minimally have a
#' POSIXct column `time`.
#' @param env data.table, as returned from [fp_read()]
#' @param header list, as returned from [fp_read()]
#'
#' @return A data.table with three or four columns:
#' * timestamp: POSIXct timestamp of the start of the 1-minute time chunk, in YYYY-mm-dd HH:MM format
#' * degC: temperature in degrees Celcius, as reported by the POD.
#' * dpm: detection-positive-minutes, 1 if at least one click is registered during the time chunk; 0 otherwise.
#' * bpm: buzz-positive-minutes, 1 if at least one feeding buzz is registered during the time chunk, 0 otherwise.
#' Note that bpm is only available if there is a 'buzz' column in the clicks data.table.
#'
#' @details
#' The reason that `clicks`, `env` and `header` must be specified separately
#' (rather than just directly passing the return value from [fp_read()]) is to
#' allow subsetting only the clicks of interest, e.g. NBHF of quality 2 and 3.
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
#' dpm <- fp_summarize(nbhf, env = dat$env, header = dat$header)
#'
#' # If we also wanted buzz-positive-minutes, we could do this first.
#' nbhf$buzz <- fp_find_buzzes(nbhf, method = "clicks")
#' # This time, when we call fp_summarize, it should detect that there's a
#' # buzz column, and automatically calculate feeding-positive-minutes as well.
#' dpm <- fp_summarize(nbhf, env = dat$env, header = dat$header)
#'
#' # Once we have DPMs, we can easily aggregate these into coarser time chunks
#' dpm_per_hour <- dpm[, .(dpm = sum(dpm)),
#'     .(date = fpod:::fp_floor_timestamp(timestamp, unit = "hour"))] # per hour
#' dpm_per_day <- dpm[, .(dpm = sum(dpm)),
#'     .(date = as.Date(timestamp))] # per day
#' dpm_per_week <- dpm[, .(dpm = sum(dpm)),
#'     .(date = fpod:::fp_floor_timestamp(timestamp, unit = "week"))] # per week
#'
#' @import data.table
#' @export
fp_summarize <- function(clicks, env, header) {

    if (!("buzz" %in% colnames(clicks) && inherits(clicks$buzz, "integer"))) {
        clicks$buzz <- NA_integer_
    }

    dat_full <- data.table(timestamp = as.POSIXct("1900-01-01 00:00", tz = "") +
                               (header$first_logged_min + env$minute)*60,
                           degC = env$degC,
                           dpm = 0L, # detection positive minutes
                           bpm = 0L) # buzz positive minutes

    dat <- clicks[, .(dpm = as.integer(.N>0), # detection positive mins
                      bpm = as.integer(sum(buzz)>0)), # buzz positive mins
                  .(timestamp = fp_floor_timestamp(time, unit = "minute"))]

    dat_full[dat, on = "timestamp", c("dpm", "bpm") := list(i.dpm, i.bpm)]
    dat_full
}
