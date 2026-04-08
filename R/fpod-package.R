#' @description
#' This package reads FPOD and CPOD data into R directly from the
#' FPOD data files (i.e. the .CP1, .CP3, .FP1 and .FP3 files). The FPOD data
#' files contain binary data, so they can't trivially be read into R using the
#' usual approach (e.g. fread or read.csv). This package decodes the binary
#' data and imports all the data in one go (i.e. header/metadata, clicks,
#' KERNO classifications, environmental data and pseudo-WAV data). It is then
#' trivial to aggregate data as you please, e.g. DPMs per time block. The
#' advantage of handling data processing in R is a long topic, but suffice it
#' to say that it 1) simplifies things (many fewer steps, as different vars
#' have to be exported in multiple goes in the official FPOD app), and more
#' importantly, 2) makes data processing transparent and reproducible.
#'
#' @author André Moan <andre.moan@hi.no> [ORCID](https://orcid.org/0000-0001-9506-2949)
#' @details
#' For more information, see:
#' * vignette 1: Type vignette("fpod", package = "fpod")
#' * vignette 2: Type vignette("advanced-usage", package = "fpod")
#' * help functions for any of the functions listed under `See Also`
#' * package website at [https://supermoan.github.io/fpod/](https://supermoan.github.io/fpod/)
#'
#' @keywords internal
#' @seealso [fp_read()], [fp_summarize()], [fp_find_buzzes()], [fp_plot()]
"_PACKAGE"

## usethis namespace: start
## usethis namespace: end
NULL
