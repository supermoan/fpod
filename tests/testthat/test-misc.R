test_that("get_khz_from_ipi works", {

    # edge cases
    ipi <- c(1, 17, 91, 256)
    case1 <- get_khz_from_ipi(121)
    case2 <- get_khz_from_ipi(c(1, 17, 91, 256))

    expect_length(case1, 1)
    expect_length(case2, 4)
    expect_equal(case1, 33)
    expect_equal(case2, c(255, 235, 44, 1))

})

test_that("get_extrapolated_amp_from_raw_amp works", {

    # edge cases
    x <- data.table(raw_amp = c(40, 222, 223, 233),
                    ipi = c(35, 35, 35, 5))

    case1 <- get_extrapolated_amp_from_raw_amp(x$raw_amp, x$ipi, FALSE)
    case2 <- get_extrapolated_amp_from_raw_amp(x$raw_amp, x$ipi, TRUE)

    expect_length(case1, nrow(x))
    expect_length(case2, nrow(x))

    expect_equal(case1, c(39, 372, 376, 416))
    expect_equal(case2, c(39, 372, 384, 416))

})
