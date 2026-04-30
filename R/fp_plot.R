#' Plot waveform and spectrum for a click
#'
#' This function constructs and plots the waveform and spectrum for a click for
#' which extra information has been recorded (IPI and SPL values for up to 21
#' cycles). By default, FPODs collect extra data for about 1% of detected clicks.
#'
#' @param x A list object, as returned from [fp_read()].
#' @param click_no integer. The click number. If NULL, then all clicks are plotted,
#' in sequential order, one at a time.
#' @param legend.pos character/logical. If character; a single keyword specifying the legend position.
#' This parameter is passed as `x` when calling [legend()]. See [legend()] for
#' details. If legend.pos is logical and FALSE, then the legend is suppressed.
#'
#' @returns Invisibly returns a numeric vector with the frequency values used
#' for plotting
#'
#' @details
#' According to the [FPOD software guide](https://www.chelonia.co.uk/f-pod/existing-user-resources/),
#' extra data are stored for a small percentage of clicks (about 1%). The clicks to
#' record are selected by a "real-time train detection algorithm" running on the FPOD.
#' The information stored is the amplitude and timing (at 250 nanosecond resolution)
#' of the peak of the soundwave. This allows for the reconstruction of the waveform
#' by fitting sine waves to the points stored.
#'
#' Note that there's an option in the FPOD app to configure the FPOD to record
#' `all` clicks rather than just a small sample..
#'
#' @examples
#' # read a FP3 file
#' fn <- fp_example("gullars_period1.FP3")
#' dat <- fp_read(fn)
#'
#' # get the click number of the first five clicks for which we have WAV data.
#' first5 <- head(unique(dat$wav$click_no))
#'
#' # plot one of them. Here, we plot number three
#' fp_plot(dat, first5[3])
#'
#' # If the legend covers the curve, we can move it somewhere else.
#' fp_plot(dat, first5[3], legend.pos = "topright")
#'
#' # If we only want to plot clicks that meet certain criteria, we have to do that
#' # manually. For example, we can plot 9 random NBHF clicks:
#' nbhf_clicks <- dat$clicks[species == "NBHF" & has_wav == TRUE, click_no]
#' old.mfrow = par()$mfrow
#' par(mfrow = c(3,3)) # we'll do 3 by 3 panels
#' for (i in sample(nbhf_clicks, size = 9)) {
#'     fp_plot(dat, click_no = i, legend.pos = FALSE)
#' }
#' par(mfrow = old.mfrow) # reset graphics device to whatever it was before
#'
#' @seealso [fp_read()]
#' @importFrom grDevices devAskNewPage
#' @importFrom graphics abline
#' @importFrom graphics axis
#' @importFrom graphics legend
#' @importFrom graphics lines
#' @importFrom graphics par
#' @export

fp_plot <- function(x, click_no = NULL, legend.pos = "topleft") {

    if (is.null(click_no)) {
        ask <- devAskNewPage()
        on.exit(devAskNewPage(ask = ask))

        click_list <- unique(x$wav$click_no)
        click_list <- click_list[which(click_list %in% x$clicks$click_no)]

        if (length(click_list) > 0) {
            # tryCatch with interrupt clause is used to prevent plot from clearing
            # if the user hits ESC during sequential plotting
            tryCatch({
                for (i in 1:length(click_list)) {
                    devAskNewPage(ask = i > 1)
                    fp_plot(x, click_no = click_list[i], legend.pos = legend.pos)
                    par(ask = FALSE)
                }
            }, interrupt = function(e) {
                devAskNewPage(ask = FALSE)
                fp_plot(x, click_no = click_list[i-1], legend.pos = legend.pos)
            })
        }
        return(invisible(NULL))
    }

    i <- data.table(click_no = click_no)
    wav <- x$wav[i, on = "click_no"]
    click <- x$clicks[i, on = "click_no"]

    if (nrow(wav) == 0 || nrow(click) == 0 || click$has_wav == FALSE) {
        stop("Click not found, or click does not have pseudo-wav data to plot")
    }

    valid_idx <- which(wav$IPI < 255)
    if(length(valid_idx) == 0) return(NULL)

    waveform <- lapply(1:length(valid_idx), function(i) {
        ipi <- wav$IPI[valid_idx[i]]
        spl <- wav$SPL[valid_idx[i]]
        spl_expanded <- fpod_conversion_tables$linear[spl]
        t <- seq(0, ipi - 1)
        cycle_wave <- spl_expanded * sin(2 * pi * (1/ipi) * t)
        data.table(cycle = i, t = t, wave = cycle_wave)
    })
    waveform <- rbindlist(waveform)

    waveform$wave[nrow(waveform)] <- 0
    waveform[, wave_scaled := wave*200/max(wave)]
    info <- c(sprintf("%.0f max wave amplitude", max(waveform$wave)),
              sprintf("%d kHz (from IPIs or duration", click$khz),
              sprintf("%d cycles logged", click$ncyc))

    old.mar <- par()$mar
    on.exit(par(mar = old.mar))
    par(mar = replace(par()$mar, 2, 7.1))

    plot(waveform$wave_scaled,type="l", las = 1,
         main = sprintf("click no %s", click_no),
         xlab="Time (us)", ylab="Frequency\n\n",
         yaxt="n", col = "yellow4", lwd = 2)

    lines(waveform[cycle < (21-click$ncyc), wave_scaled], col = "red")
    abline(h = 0, lty = "dashed")
    axis(2, las=1, at = seq(-200, 200, 100), labels = sprintf("%skHz", seq(0, 200, 50)))
    if (!(inherits(legend.pos, "logical") && legend.pos == FALSE)) {
        legend(x = legend.pos, legend = info, inset = 0.05)
    }
    invisible(waveform$wave_scaled)
}

