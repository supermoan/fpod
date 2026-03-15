# Calculates minute-resolution summaries of clicks

Calculates minute-resolution summaries of clicks

## Usage

``` r
fp_summarize(x)
```

## Arguments

- x:

  data.table where each row is a click, as the "clicks" element in the
  list object returned by
  [`fp_read()`](https://supermoan.github.io/fpod/reference/fp_read.md).
  Each row must minimally have a POSIXct column `time`. The return value
  of
  [`fp_read()`](https://supermoan.github.io/fpod/reference/fp_read.md)
  is also accepted with a warning, provided that the clicks data.table
  is present .

## Value

A data.table with three or four columns:

- time: POSIXct timestamp of the start of the 1-minute time chunk, in
  YYYY-mm-dd HH:MM format

- dpm: detection-positive-minutes, 1 if at least one click is registered
  during the time chunk; 0 otherwise.

- bpm: buzz-positive-minutes, 1 if at least one feeding buzz is
  registered during the time chunk, 0 otherwise. Note that bpm is only
  available if there is a 'buzz' column in the clicks data.table, e.g.
  from first calling
  [`fp_find_buzzes()`](https://supermoan.github.io/fpod/reference/fp_find_buzzes.md)

## See also

[`fp_find_buzzes()`](https://supermoan.github.io/fpod/reference/fp_find_buzzes.md),
`lubridate::floor_date()`

## Examples

``` r
# first read some FPOD data
fn <- fp_example("gullars_period1.FP3")
dat <- fp_read(fn)

# extract porpoise clicks of quality Hi and Mod
nbhf <- dat$clicks[species == "NBHF" & quality_level >= 2]

# get a simple summary, with timestamp, degC and dpm.
dpm <- fp_summarize(nbhf)

# If we also wanted buzz-positive-minutes, we could do this first.
nbhf$buzz <- fp_find_buzzes(nbhf, method = "clicks")

# This time, when we call fp_summarize, it should detect that there's a
# buzz column, and automatically calculate feeding-positive-minutes as well.
dpm <- fp_summarize(nbhf)

# Once we have DPMs, we can easily aggregate these into coarser time chunks
dpm_per_hour <- dpm[, .(dpm = sum(dpm)),
    .(date = as.POSIXct(trunc(time, unit = "hours")))] # per hour
dpm_per_day <- dpm[, .(dpm = sum(dpm)),
    .(date = as.Date(time))] # per day
dpm_per_month <- dpm[, .(dpm = sum(dpm)),
    .(date = as.POSIXct(trunc(time, unit = "months")))] # per month
```
