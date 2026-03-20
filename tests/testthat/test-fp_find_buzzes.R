test_that("fp_find_buzzes works", {

    fn <- fp_example("gullars_period1.FP3")
    dat <- fp_read(fn)
    x <- dat$clicks[species == "NBHF" & quality_level >= 2]

    buzz <- fp_find_buzzes(x)

    dat2 <- data.frame(time = 1)

    # correct usage and expected values
    expect_length(buzz, nrow(x))
    expect_equal(sum(buzz), 8895L)

    # incorrect usage
    expect_error(fp_find_buzzes(dat), "x must be a data.table with click timestamps in a POSIXct")
    expect_error(fp_find_buzzes(dat2, "x must be a data table with click timestamps"))
    expect_error(fp_find_buzzes(dat$clicks, method = 3))

})

test_that("fp_find_buzzes trains method works", {
    skip_if_not_installed("mixtools")
    fn <- fp_example("gullars_period1.FP3")
    dat <- fp_read(fn)
    x <- dat$clicks[species == "NBHF" & quality_level >= 2]
    buzz <- fp_find_buzzes(x, method = "trains")

    # can't be sure of exact number due to stochasticity
    # inherent in the EM algorithm, but we do expect a nonzero sum
    expect_true(sum(buzz) > 0)

    x$time[1] <- x$time[nrow(x)]
    expect_warning(fp_find_buzzes(x, method = "trains"), "clicks are not ordered")

    bad_clicks <- data.table(time = as.POSIXct("2024-01-01")+5:0)
    expect_error(fp_find_buzzes(bad_clicks, method = "trains"), "all inter-click-intervals are NA")

})
