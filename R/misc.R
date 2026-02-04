#' misc support functions -
#'
#'

get_khz_from_ipi <- function(ipi) {
    fpod_conversion_tables$ipi[ipi]
}

get_extrapolated_amp_from_raw_amp <- function(raw_amp, ipi, use_ext_amps) {

    ret <- data.table(raw_amp = raw_amp, ipi = ipi, real_amp = NA_integer_)
    ret[raw_amp == 0, real_amp := 1]

    if (use_ext_amps == TRUE) {
        ret[ipi >= 10 & raw_amp > 222,
            real_amp := fpod_conversion_tables$clipped[J(peak = raw_amp, ici = ipi), on = c("peak","ici"), val]]
    }

    ret[is.na(real_amp), real_amp := fpod_conversion_tables$linear[raw_amp]]
    ret$real_amp
}



