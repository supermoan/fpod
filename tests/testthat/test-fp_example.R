test_that("fp_example works", {

    case1 <- fp_example()
    case2 <- fp_example("gullars_period1.FP3")

    expect_type(case1, "character")
    expect_true(length(case1) >= 1)

    expect_equal(basename(case2), "gullars_period1.FP3")

    expect_error(fp_example("other_file.FP3"))

})
