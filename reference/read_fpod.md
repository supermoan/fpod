# Read FPOD data

This function reads an FPOD or CPOD data file (FP1, FP3, CP1, CP3) into
R.

## Usage

``` r
read_fpod(file, tz = "", simplify = TRUE, amp = "extended")
```

## Arguments

- file:

  a character string. The path to the FPOD (or CPOD) data file.

- tz:

  a character string. The time zone specification to be used for
  calculating dates. Passed unchanged to
  [`as.POSIXct()`](https://rdrr.io/r/base/as.POSIXlt.html).

- simplify:

  logical. If TRUE, simplifies the clicks data.table by stripping away
  some columns, such as `clk_ipi_range`, `ipi_pre_max`, `amp_reversals`,
  `duration`, and `has_wav`.

- amp:

  a character string. With `amp`="extended", higher values are
  extrapolated from the duration of clipping and the IPI. For any other
  values of amp, the compressed SPL values recorded by the FPOD are used
  directly.

## Value

A list, with one or more of the following data.frames (or data.tables,
if available):

- header: a list with pod name, coordinates, starting time, stopping
  time, user notes, etc.

- clicks: A data.frame (or data.table) with data about each click. See
  details.

- wav (only FPx files): pseudo-wav data - inter-peak-intervals and raw
  amplitudes for a subset of clicks

- env: misc data, ambient temperature (in deg C) and battery voltage per
  stack (in units of 10 millivolts)

## Details

The clicks data.frame contains the following columns:

- time: The time and date of the click, at microsecond resolution. Note
  that R might only display dates and times to a second precision, but
  any date or time calculations will use the full precision.

- minute: minutes elapsed, since starting the FPOD

- microsec: microseconds elapsed, since the start of the minute.

- click_no: an ID number that uniquely identifies the click.

- train_id: an ID number from the KERNO classifier, reset for each
  minute.

- species: the species classification from the KERNO classifier

- quality_level: the quality level of the classification, 1 to 3.

- echo: TRUE if the KERNO classifier thinks this click might be an echo
  of another click that has already been classified.

- ncyc: number of cycles in click. This is a proxy for the click
  duration.

- pkat: the number of the cycle with the highest amplitude

- clk_ipi_range: range of inter-peak-intervals (IPIs) among cycles in
  click

- ipi_pre_max: the IPI before pkat, in 250 nanosecond units

- ipi_at_max: the IPI at pkat, in 250 nanosecond units

- khz: The frequency (in kHz) of the peak cycle.

- amp_at_max: the peak amplitude (SPL) of the loudest cycle

- amp_reversals: the number of amplitude reversals

- duration:

- has_wav: TRUE if there is a pseudo-WAV recorded for this click.

## Examples

``` r
# read a FP3 file
dat <- read_fpod(file = "helga period 1.FP3")
#> Error in read_fpod(file = "helga period 1.FP3"): could not find function "read_fpod"

# show misc. information (pod number, deployment date, etc.)
dat$header
#> Error: object 'dat' not found

# tally up the number of clicks in each species category
table(dat$clicks$species)
#> Error: object 'dat' not found

# Calculate Detection Positive Minutes (DPMs) for porpoises per day
 dpm_per_day <- dat$clicks[species=="NBHF", length(unique(minute(time))), as.Date(time)]
#> Error: object 'dat' not found
```
