#' Read FPOD data
#'
#' This function reads an FPOD or CPOD data file (FP1, FP3, CP1, CP3) into R.
#'
#' @param file a character string. The path to the FPOD (or CPOD) data file.
#' @param tz a character string. The time zone used to display times, e.g.
#'   "Europe/Oslo". Times are always calculated in UTC; `tz` only affects how
#'   they are displayed. Default "UTC".
#' @param simplify logical. If TRUE, simplifies the clicks data.table by
#'   stripping away some columns, such as `clk_ipi_range`, `ipi_pre_max`,
#'   `amp_reversals`, `duration`, and `has_wav`.
#' @param amp a character string. With `amp`="extended", higher values are
#'   extrapolated from the duration of clipping and the IPI. For any other
#'   values of amp, the compressed SPL values recorded by the FPOD are used
#'   directly.
#' @param time_offset numeric (seconds) or [difftime]. Added to all times in
#'   the file; negative values are subtracted. Use it to convert the POD clock
#'   to UTC and to correct a clock known to be wrong. For example, a clock set
#'   to Central European summer time (UTC+2) is 2 hours ahead of UTC, so use
#'   `as.difftime(-2, units = "hours")`; a clock that was 2 days slow needs
#'   `as.difftime(2, units = "days")`. Default 0 (the POD clock is assumed to
#'   run on UTC). A plain number is taken as seconds, and a warning is given if
#'   it is under one hour, since hours given without units are an easy
#'   mistake; use a difftime to avoid the warning.
#'
#' @returns A list, with one or more of the following data.frames (or
#'   data.tables, if available):
#' * header: a list with pod name, coordinates, starting time, stopping time, user
#'   notes, etc.
#' * clicks: A data.frame (or data.table) with data about each click. See details.
#' * wav (only FPx files): pseudo-wav data - inter-peak-intervals (in 250 ns units)
#'   and raw amplitudes for a subset of clicks
#' * env: misc data, angle from vertical (in degrees), ambient temperature (in deg C),
#'   battery voltage per stack (in units of volts), which battery column
#'   is in use, and the pod on/off state.
#'
#' @details The clicks data.frame contains the following columns:
#' * pod: the ID number of the pod
#' * time: The time and date of the click, at microsecond resolution. Note that R might
#'   only display dates and times to a second precision, but any date or time
#'   calculations will use the full precision.
#' * minute: minutes elapsed, since starting the FPOD
#' * microsec: microseconds elapsed, since the start of the minute.
#' * click_no: an ID number that uniquely identifies the click.
#' * train_id: an ID number from the KERNO classifier, reset for each minute.
#' * species: the species classification from the KERNO classifier
#' * quality_level: the quality level of the classification, 0 (?/echo), 1 (Lo),
#'   2 (Mod) or 3 (Hi).
#' * echo: TRUE if the KERNO classifier thinks this click might be an echo of
#'   another click that has already been classified.
#' * ncyc: number of cycles in click. This is a proxy for the click duration.
#' * pkat: the number of the cycle with the highest amplitude
#' * clk_ipi_range: range of inter-peak-intervals (IPIs) among cycles in click
#' * ipi_pre_max: the IPI before pkat, in 250 nanosecond units
#' * ipi_at_max: the IPI at pkat, in 250 nanosecond units
#' * khz: The frequency (in kHz) of the peak cycle.
#' * amp_at_max: the peak amplitude (SPL) of the loudest cycle
#' * amp_reversals: the number of amplitude reversals
#' * duration: click duration
#' * has_wav: TRUE if there is a pseudo-WAV recorded for this click.
#'
#' POD times are stored as minutes since 1899-12-30 (the Delphi/Excel
#' convention), as read from the POD clock. `time_offset` is added to convert
#' them to UTC, and they are then displayed in `tz`. The corrected first and
#' last logged times are also returned as `header$first_logged_time` and
#' `header$last_logged_time`.
#'
#' A POD clock keeps the time it was set to, with no daylight saving changes,
#' so a clock set to summer time stays on summer time through the winter. If a
#' clock is known to have been wrong for a whole file, include the error in
#' `time_offset` too, e.g. 2 days for a clock that was 2 days slow. See
#' examples.
#'
#' @examples
#' # read a FP3 file
#' fn <- fp_example("gullars_period1.FP3")
#' dat <- fp_read(fn)
#'
#' # show misc. information (pod number, deployment date, etc.)
#' dat$header
#'
#' # a POD clock set to Norwegian summer time (UTC+2) and known to be 2 days
#' # slow, with times displayed in Norwegian local time
#' dat <- fp_read(fn, tz = "Europe/Oslo",
#'                time_offset = as.difftime(2, units = "days") -   # clock 2 days slow
#'                              as.difftime(2, units = "hours"))   # clock on UTC+2
#'
#' # show battery levels and recorded temperatures for each minute
#' dat$env
#'
#' # tally up the number of clicks in each species category
#' table(dat$clicks$species)
#'
#' @seealso [fp_find_buzzes()], [fp_summarize()]
#' @import data.table
#' @export
#'
fp_read <- function(file, tz = "UTC", simplify = TRUE, amp = "extended",
                    time_offset = 0) {

    if (!file.exists(file)) {
        stop("File does not exist!")
    }

    if (!is.numeric(time_offset) && !inherits(time_offset, "difftime") ||
        length(time_offset) != 1L) {
        stop("time_offset must be a single number (seconds) or a difftime")
    }

    if (inherits(time_offset, "difftime")) {
        time_offset <- as.numeric(time_offset, units = "secs")
    } else if (time_offset != 0 && abs(time_offset) < 3600) {
        warning("time_offset is ", time_offset, " seconds; did you mean hours? ",
                "Use e.g. as.difftime(", time_offset, ", units=\"hours\" to be explicit")
    }

    ret <- readFPOD(file)
    type <- toupper(substr(file, nchar(file)-2, nchar(file)))

    # POD times are minutes since 1899-12-30 on the POD clock. Work in UTC
    # (POD clocks have no daylight saving time), add the user's time_offset
    # to get true UTC; `tz` only sets the display.
    origin <- as.POSIXct("1899-12-30", tz = "UTC") + time_offset
    attr(origin, "tzone") <- tz

    if ("header" %in% names(ret)) {
        ret$header$first_logged_time <- origin + ret$header$first_logged_min * 60
        ret$header$last_logged_time <- origin + ret$header$last_logged_min * 60
    }

    if ("clicks" %in% names(ret)) {
        if (nrow(ret$clicks) > 0) {
            ret$clicks$pod <- ret$header$pod_id
            ret$clicks$time <- origin +
                (ret$header$first_logged_min + ret$clicks$minute) * 60 +
                ret$clicks$microsec / 1e6
        } else {
            # even if there are no clicks, add a time column to make the
            # clicks data.table rbind-friendly in lapply calls and similar.
            ret$clicks$pod <- integer()
            ret$clicks$time <- origin[0] # to avoid losing tz for empty files
        }

        col_order <- c(ncol(ret$clicks)-1, ncol(ret$clicks), seq(1, ncol(ret$clicks) - 2))

        data.table::setDT(ret$clicks)
        data.table::setcolorder(ret$clicks, col_order)

        if (type %in% c("FP1", "FP3")) {
            if ("header" %in% names(ret) && "fpga_ver" %in% names(ret$header) && ret$header[["fpga_ver"]] > 801) {
                local_ipi <- ret$clicks$ipi_at_max
            } else {
                local_ipi <- ret$clicks$ipi_pre_max
            }

            if (amp[1] == "extended") {
                use_extended_amps <- "header" %in% names(ret) &&
                    "has_extended_amps" %in% names(ret$header) &&
                    ret$header[["has_extended_amps"]]
                ret$clicks[, amp_at_max := get_extrapolated_amp_from_raw_amp(amp_at_max, local_ipi, use_extended_amps)]
            }
            ret$clicks[, khz := get_khz_from_ipi(local_ipi)]
        }

        if (simplify == TRUE) {
            ret$clicks[, clk_ipi_range := NULL]
            ret$clicks[, ipi_pre_max := NULL]
            ret$clicks[, ipi_at_max := NULL]
            ret$clicks[, amp_reversals := NULL]
            ret$clicks[, duration := NULL]
        }

        setattr(ret$clicks, "start", origin + ret$header$first_logged_min * 60)

    }

    if ("env" %in% names(ret)) {
        data.table::setDT(ret$env)

        ret$env[, time := origin + (ret$header$first_logged_min + minute) * 60]

        if ("clicks" %in% names(ret) && all(c("minute", "pod_on") %in% colnames(ret$env))) {
            setattr(ret$clicks, "on", ret$env[pod_on == TRUE, minute])
            # all minutes in the file, needed by fp_summarize(fpod_compat = TRUE)
            setattr(ret$clicks, "minutes", ret$env$minute)
        }

        if ("bat1v" %in% colnames(ret$env)) {
            ret$env[, bat1v := bat1v/10]
        }
        if ("bat2v" %in% colnames(ret$env)) {
            ret$env[, bat2v := bat2v/10]
        }

        if ("angle" %in% colnames(ret$env)) {
            ret$env[fpod_conversion_tables$angles,
                    on = c("angle"="cp3_angle"), angle := actual_angle]
        }
        data.table::setcolorder(ret$env, "time") # set `time` as first col
        setindex(ret$env, NULL)
    }

    if ("wav" %in% names(ret) && nrow(ret$wav) > 0) {
       data.table::setDT(ret$wav)
        #if ("clicks" %in% names(ret)) {
            #ret$wav[ret$clicks, on = "click_no", ncyc := i.ncyc]
            #ret$wav[, cycle := 1:.N, click_no]
            #ret$wav[, first_cycle := pmax(1, .N-ncyc+1), click_no]
            #ret$wav <- ret$wav[cycle >= first_cycle]
            #ret$wav[, c("cycle", "ncyc", "first_cycle") := NULL]
        #}
    }
    if ("env" %in% names(ret)) ret$env[]
    if ("clicks" %in% names(ret)) ret$clicks[]

    ret
}

