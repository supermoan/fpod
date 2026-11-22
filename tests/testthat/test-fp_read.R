test_that("FP3 is read correctly", {
    fn <- fp_example("gullars_period1.FP3")
    dat <- fp_read(fn)
    dat2 <- fp_read(fn, amp = "")

    # structure of return value
    expect_type(dat, "list")
    expect_length(c("header", "clicks", "env") %in% names(dat), 3)

    # header data
    expect_equal(dat$header$pod_id, 7660L)
    expect_equal(dat$header$first_logged_min, 65709000L)
    expect_equal(dat$header$last_logged_min, 65723400L)
    expect_equal(dat$header$water_depth, 30L)
    expect_equal(dat$header$deployment_depth, 0L)
    expect_equal(dat$header$lat_text, "70,03332")
    expect_equal(dat$header$lon_text, "18,9162")
    expect_equal(dat$header$clicks_in_fp1, 48680158L)

    # env data
    expect_equal(nrow(dat$env), 14400L)
    expect_equal(ncol(dat$env), 10L)

    # clicks data
    expect_equal(nrow(dat$clicks), 82637L)
    expect_equal(ncol(dat$clicks), 14L)
    expect_equal(sum(dat$clicks$species == "NBHF"), 51590L)
    expect_equal(dat$clicks$amp_at_max[1], 30L)
    expect_equal(dat2$clicks$amp_at_max[1], 31L)

    # misc
    expect_error(fp_read(fn, tz = 1), "invalid 'tz' value")
    expect_error(fp_read("gullars.FP3"), "File does not exist")

})

test_that("times use the 1899-12-30 origin and tz only affects display", {
    fn <- fp_example("gullars_period1.FP3")
    utc <- fp_read(fn)
    osl <- fp_read(fn, tz = "Europe/Oslo")

    expect_equal(utc$header$first_logged_time,
                 as.POSIXct("2024-12-05 06:00:00", tz = "UTC"))
    expect_equal(as.numeric(osl$clicks$time), as.numeric(utc$clicks$time))
    expect_equal(attr(osl$clicks$time, "tzone"), "Europe/Oslo")
})

test_that("time_offset shifts every time by the same amount", {
    fn <- fp_example("gullars_period1.FP3")
    a <- fp_read(fn)
    b <- fp_read(fn, time_offset = as.difftime(46, units = "hours"))
    shift <- 46 * 3600

    expect_equal(as.numeric(b$clicks$time - a$clicks$time, units = "secs"),
                 rep(shift, nrow(a$clicks)))
    expect_equal(as.numeric(b$header$first_logged_time - a$header$first_logged_time,
                            units = "secs"), shift)
    expect_equal(as.numeric(attr(b$clicks, "start") - attr(a$clicks, "start"),
                            units = "secs"), shift)
    expect_equal(as.numeric(b$env$time - a$env$time, units = "secs"),
                 rep(shift, nrow(a$env)))
})

test_that("time_offset accepts seconds or difftime and checks its input", {
    fn <- fp_example("gullars_period1.FP3")
    a <- fp_read(fn, time_offset = 7200)
    b <- fp_read(fn, time_offset = as.difftime(2, units = "hours"))
    expect_equal(a$clicks$time, b$clicks$time)

    expect_warning(fp_read(fn, time_offset = 2), "did you mean hours")
    expect_no_warning(fp_read(fn, time_offset = as.difftime(30, units = "mins")))
    expect_error(fp_read(fn, time_offset = c(1, 2)), "single number")
    expect_error(fp_read(fn, time_offset = "2h"), "single number")
})

test_that("env minutes are 0-based and line up with clicks", {
    dat <- fp_read(fp_example("gullars_period1.FP3"))
    expect_equal(dat$env$minute, seq(0L, nrow(dat$env) - 1L))
    expect_true(all(dat$clicks$minute %in% dat$env$minute))
    expect_equal(dat$env$time,
                 dat$header$first_logged_time + dat$env$minute * 60)
})

test_that("F-POD battery voltages are in volts", {
    dat <- fp_read(fp_example("gullars_period1.FP3"))
    expect_equal(dat$env$bat1v[1], 7.9)
    expect_equal(dat$env$bat2v[1], 7.0)
})

test_that("pod_on is complete and covers every minute with clicks", {
    dat <- fp_read(fp_example("gullars_period1.FP3"))
    expect_type(dat$env$pod_on, "logical")
    expect_false(anyNA(dat$env$pod_on))
    expect_true(all(dat$env[minute %in% dat$clicks$minute, pod_on]))
})

test_that("click counts and time lost are read from minute records", {
    dat <- fp_read(fp_example("gullars_period1.FP3"))
    expect_true(all(c("n_clicks_all", "time_lost") %in% names(dat$env)))
    expect_equal(sum(dat$env$time_lost > 0), 21L)
    expect_true(all(dat$env$time_lost >= 0 & dat$env$time_lost < 1))
    expect_true(all(dat$env[time_lost > 0, n_clicks_all] > 15000))
    expect_true(median(dat$env$n_clicks_all) < 1000)
})
