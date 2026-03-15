test_that("fp_summarize works", {
    fn <- fp_example("gullars_period1.FP3")
    dat <- fp_read(fn)
    dat2 <- copy(dat)
    dat2$clicks$pod[2] <- 1

    start <- attr(dat$clicks, "start")
    on <- attr(dat$clicks, "on")

    s1 <- fp_summarize(dat$clicks)
    dat$clicks$buzz <- fp_find_buzzes(dat$clicks)
    s2 <- fp_summarize(dat$clicks)

    # correct usage, expected results
    expect_equal(nrow(s1), nrow(s2))
    expect_equal(nrow(s1), 14400L)
    expect_equal(sum(s1$dpm), 726L)
    expect_equal(sum(s2$bpm), 377L)
    expect_equal(nrow(s1), length(on))

    # are we actually summing by minute?
    # sample 100 rows and compare the timestamp of each with that of its preceding row
    i <- sample(2:nrow(s1), size = 100)
    dt <- sapply(i, function(i) difftime(s1$time[i], s1$time[i-1], unit="mins"))
    expect_true(all(dt == 1))

    # incorrect usage, or usage on malformed data
    expect_warning(fp_summarize(dat), "x is a list")
    expect_warning(fp_summarize(dat2$clicks), "not all pod values are identical")

    # misformed attributes #1
    setattr(dat$clicks, "start", NULL)
    expect_error(fp_summarize(dat$clicks), "x lacks attributes")

    # misformed attributes #2
    setattr(dat$clicks, "start", start)
    setattr(dat$clicks, "on", NULL)
    expect_error(fp_summarize(dat$clicks), "x lacks attributes")

    # misformed attributes #3
    setattr(dat$clicks, "start", 1)
    setattr(dat$clicks, "on", on)
    expect_error(fp_summarize(dat$clicks), "x has malformed attributes")

    # misformed attributes #4
    setattr(dat$clicks, "start", start)
    setattr(dat$clicks, "on", "character")
    expect_error(fp_summarize(dat$clicks), "x has malformed attributes")

})
