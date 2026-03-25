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
    expect_equal(ncol(dat$env), 7L)

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
