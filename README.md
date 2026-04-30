
<!-- README.md is generated from README.Rmd. Please edit that file -->

<!-- badges: start -->

[![R-CMD-check](https://github.com/supermoan/fpod/actions/workflows/R-CMD-check.yaml/badge.svg)](https://github.com/supermoan/fpod/actions/workflows/R-CMD-check.yaml)
<!-- badges: end -->

# fpod

The goal of fpod is to provide a means to directly load FPOD and CPOD
data files into R. The FPOD data files contain binary data, so they
can’t trivially be read into R using the usual approach (e.g. fread or
read.csv). This package decodes the binary data and imports all the data
in one go (i.e. header/metadata, clicks, KERNO classifications,
environmental data and pseudo-WAV data). It is then trivial to aggregate
and visualize data as you please, e.g. summing DPMs per time block or
showing reconstructed waveforms. The advantage of handling data
processing in R is a long topic, but suffice it to say that it 1)
simplifies things (many fewer steps, as different vars have to be
exported in multiple goes in the official FPOD app), and more
importantly, 2) makes data processing 100% transparent and reproducible.

## Overview

- `fp_read()` reads a CP1, CP3, FP1 or FP3 binary data file
- `fp_summarize()` calculates minute-resolution summaries of clicks
- `fp_find_buzzes()` finds harbour porpoise buzzes in a subset of clicks

## Installation

``` r
# install from CRAN (recommended)
install.packages("fpod")

# Alternatively, you can install the development version of fpod from GitHub:
#install.packages("pak")
pak::pak("supermoan/fpod")
```

## Quick start

If you just want to get started, load the package, and call `fp_read()`
on your FPOD data, like so:

``` r
library(fpod)
fn <- fp_example("gullars_period1.FP3")
dat <- fp_read(fn)
```

This will give you access to most of the information in the FP3 file,
including header/metadata, clicks data and misc other data, such as
battery levels.

For more examples, see the [getting started
vignette](https://supermoan.github.io/fpod/articles/fpod.html), [the
advanced usage
vignette](https://supermoan.github.io/fpod/articles/advanced-usage.html)
and the help files for each individual function:
[?fp_read](https://supermoan.github.io/fpod/reference/fp_read.html),
[?fp_summarize](https://supermoan.github.io/fpod/reference/fp_summarize.html)
[?fp_find_buzzes](https://supermoan.github.io/fpod/reference/fp_find_buzzes.html).
[?fp_plot](https://supermoan.github.io/fpod/reference/fp_plot.html)

## Disclaimer

This package is not affiliated with the manufacturer of the CPOD and
FPOD hardware, [Chelonia](https://www.chelonia.co.uk/), but is possible
thanks to Chelonia generously sharing the source code of the FPOD app.
