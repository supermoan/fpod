# include this call to globalVariables to satisfy devtools::check()
utils::globalVariables(c(".", "fpod_conversion_tables", "amp_at_max", "khz",
                         "clk_ipi_range", "ipi_pre_max", "ipi_at_max",
                         "amp_reversals", "duration", "ncyc", "i.ncyc", "cycle",
                         "click_no", "first_cycle", "buzz", "time", "i.dpm",
                         "i.bpm", "amp_at_max", "real_amp", "J", "val", "angle",
                         "actual_angle"))

#' Internal helper function to lookup kHz values from inter-peak-intervals (IPIs)
#'
#' @param ipi A vector of IPIs
#' @return A vector of kHz values of the asme length as `ipi`
#' @noRd
get_khz_from_ipi <- function(ipi) {
    fpod_conversion_tables$ipi[ipi]
}

#' Internal helper function to extrapolate amplitudes from raw amplitudes
#' @param raw_amp numeric vector of raw amplitudes
#' @param ipi numeric vector of inter-peak-intervals
#' @param use_ext_amps logical, TRUE or FALSE
#'
#' @return a vector of extrapolated amplitudes
#' @noRd
#'
get_extrapolated_amp_from_raw_amp <- function(raw_amp, ipi, use_ext_amps) {
    ret <- data.table(raw_amp = raw_amp, ipi = ipi, real_amp = NA_integer_)
    ret[raw_amp == 0, real_amp := 1]

    if (use_ext_amps == TRUE) {
        val <- fpod_conversion_tables$clipped[ret[ipi >= 10 & raw_amp > 222],
                                       on = c("peak"="raw_amp", "ipi"), val]
        ret[ipi >= 10 & raw_amp > 222, real_amp := val]
    }

    ret[is.na(real_amp), real_amp := fpod_conversion_tables$linear[raw_amp]]
    ret$real_amp
}

