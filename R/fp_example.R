#' Get path to fpod example
#'
#' @param path Name of the file. If NULL, all example files are listed.
#'
#' @examples
#' # get a list all example files
#' fp_example()
#'
#' # get the path for this particular file
#' fp_example("gullars_period1.FP3")
#'
#' @export
#'

fp_example <- function(path = NULL) {
    if (is.null(path)) {
        dir(system.file("extdata", package = "fpod"))
    } else {
        system.file("extdata", path, package = "fpod", mustWork = TRUE)
    }
}

