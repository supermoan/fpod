#' Read FPOD data
#'
#' This function reads an FPOD or CPOD data file (FP1, FP3, CP1, CP3) into R.
#' @param file a character string. The path to the FPOD (or CPOD) data file.
#' @param tz a character string. The time zone specification to be used for
#' calculating dates. Passed unchanged to [as.POSIXct()].
#' @param simplify logical. If TRUE, simplifies the clicks data.table by stripping
#' away some columns, such as `clk_ipi_range`, `ipi_pre_max`, `amp_reversals`,
#' `duration`, and `has_wav`.
#' @param amp a character string. With `amp`="extended", higher values are extrapolated
#' from the duration of clipping and the IPI. For any other values of amp, the
#' compressed SPL values recorded by the FPOD are used directly.
#'
#' @returns A list, with one or more of the following data.frames (or data.tables, if available):
#' * header: a list with pod name, coordinates, starting time, stopping time, user notes, etc.
#' * clicks: A data.frame (or data.table) with data about each click. See details.
#' * wav (only FPx files): pseudo-wav data - inter-peak-intervals and raw amplitudes for a subset of clicks
#' * env: misc data, ambient temperature (in deg C) and battery voltage per stack (in units of 10 millivolts)
#'
#' @details
#' The clicks data.frame contains the following columns:
#' * time: The time and date of the click, at microsecond resolution. Note that R might
#' only display dates and times to a second precision, but any date or time calculations
#' will use the full precision.
#' * minute: minutes elapsed, since starting the FPOD
#' * microsec: microseconds elapsed, since the start of the minute.
#' * click_no: an ID number that uniquely identifies the click.
#' * train_id: an ID number from the KERNO classifier, reset for each minute.
#' * species: the species classification from the KERNO classifier
#' * quality_level: the quality level of the classification, 1 (Lo), 2 (Mod) or 3 (Hi). 
#' * echo: TRUE if the KERNO classifier thinks this click might be an echo of another click that has already been classified.
#' * ncyc: number of cycles in click. This is a proxy for the click duration.
#' * pkat: the number of the cycle with the highest amplitude
#' * clk_ipi_range: range of inter-peak-intervals (IPIs) among cycles in click
#' * ipi_pre_max: the IPI before pkat, in 250 nanosecond units
#' * ipi_at_max: the IPI at pkat, in 250 nanosecond units
#' * khz: The frequency (in kHz) of the peak cycle.
#' * amp_at_max: the peak amplitude (SPL) of the loudest cycle
#' * amp_reversals: the number of amplitude reversals
#' * duration:
#' * has_wav: TRUE if there is a pseudo-WAV recorded for this click.
#'
#' @examples
#' # read a FP3 file
#' dat <- read_fpod(file = "helga period 1.FP3")
#'
#' # show misc. information (pod number, deployment date, etc.)
#' dat$header
#'
#' # tally up the number of clicks in each species category
#' table(dat$clicks$species)
#'
#' # Calculate Detection Positive Minutes (DPMs) for porpoises per day
#'  dpm_per_day <- dat$clicks[species=="NBHF", length(unique(minute(time))), as.Date(time)]
#' @import data.table
#' @export
#'
read_fpod <- function(file, tz = "", simplify = TRUE, amp = "extended") {

    ret <- readFPOD(file)
    type <- toupper(substr(file, nchar(file)-2, nchar(file)))

    if ("clicks" %in% names(ret)) {
        if (nrow(ret$clicks) > 0) {
            ret$clicks$time = as.POSIXct("1900-01-01 00:00", tz = tz) +
                (ret$header$first_logged_min + ret$clicks$minute) * 60 +
                ret$clicks$microsec / 1e6
        }

        col_order <- c(ncol(ret$clicks), seq(1, ncol(ret$clicks) - 1))

        data.table::setDT(ret$clicks)
        data.table::setcolorder(ret$clicks, col_order)

        if (type %in% c("FP1", "FP3")) {
            if ("header" %in% names(ret) && "fpga_ver" %in% names(ret$header) && ret$header["fpga_ver"] > 801) {
                local_ipi <- ret$clicks$ipi_at_max
            } else {
                local_ipi <- ret$clicks$ipi_pre_max
            }

            if (amp[1] == "extended") {
                use_extended_amps <- "header" %in% names(ret) &&
                    "has_extended_amps" %in% names(ret$header) &&
                    ret$header["has_extended_amps"]
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

    }

    if ("env" %in% names(ret)) {
        data.table::setDT(ret$env)
    }

    if ("wav" %in% names(ret) && nrow(ret$wav) > 0) {
       data.table::setDT(ret$wav)
        if ("clicks" %in% names(ret)) {
            ret$wav[ret$clicks, on = "click_no", ncyc := i.ncyc]
            ret$wav[, cycle := 1:.N, click_no]
            ret$wav[, first_cycle := pmax(1, .N-ncyc+1), click_no]
            ret$wav <- ret$wav[cycle >= first_cycle]
            ret$wav[, c("cycle", "ncyc", "first_cycle") := NULL]
        }
    }

    ret
}
