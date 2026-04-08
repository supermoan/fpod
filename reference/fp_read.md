# Read FPOD data

This function reads an FPOD or CPOD data file (FP1, FP3, CP1, CP3) into
R.

## Usage

``` r
fp_read(file, tz = "", simplify = TRUE, amp = "extended")
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

- wav (only FPx files): pseudo-wav data - inter-peak-intervals (in 250
  ns units) and raw amplitudes for a subset of clicks

- env: misc data, angle from vertical (in degrees), ambient temperature
  (in deg C), battery voltage per stack (in units of volts), which
  battery column is in use, and the pod on/off state.

## Details

The clicks data.frame contains the following columns:

- pod: the ID number of the pod

- time: The time and date of the click, at microsecond resolution. Note
  that R might only display dates and times to a second precision, but
  any date or time calculations will use the full precision.

- minute: minutes elapsed, since starting the FPOD

- microsec: microseconds elapsed, since the start of the minute.

- click_no: an ID number that uniquely identifies the click.

- train_id: an ID number from the KERNO classifier, reset for each
  minute.

- species: the species classification from the KERNO classifier

- quality_level: the quality level of the classification, 0 (?/echo), 1
  (Lo), 2 (Mod) or 3 (Hi).

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

- duration: click duration

- has_wav: TRUE if there is a pseudo-WAV recorded for this click.

## See also

[`fp_find_buzzes()`](https://supermoan.github.io/fpod/reference/fp_find_buzzes.md),
[`fp_summarize()`](https://supermoan.github.io/fpod/reference/fp_summarize.md)

## Examples

``` r
# read a FP3 file
fn <- fp_example("gullars_period1.FP3")
dat <- fp_read(fn)

# show misc. information (pod number, deployment date, etc.)
dat$header
#> $pod_id
#> [1] 7660
#> 
#> $first_logged_min
#> [1] 65709000
#> 
#> $last_logged_min
#> [1] 65723400
#> 
#> $water_depth
#> [1] 30
#> 
#> $deployment_depth
#> [1] 0
#> 
#> $lat_text
#> [1] "70,03332"
#> 
#> $lon_text
#> [1] "18,9162"
#> 
#> $location_text
#> [1] ""
#> 
#> $notes_text
#> [1] ""
#> 
#> $gmt_text
#> [1] ""
#> 
#> $pic_ver
#> [1] 23
#> 
#> $fpga_ver
#> [1] 1034
#> 
#> $extended_amps
#> [1] TRUE
#> 
#> $clicks_in_fp1
#> [1] 48680158
#> 
#> $filename
#> [1] "/home/runner/work/_temp/Library/fpod/extdata/gullars_period1.FP3"
#> 

# show battery levels and recorded temperatures for each minute
dat$env
#>        minute angle  degC bat1v bat2v bat_use pod_on
#>         <int> <int> <int> <num> <num>   <int> <lgcl>
#>     1:      1    36     6  1.58  1.40       1   TRUE
#>     2:      2    36     6  1.58  1.38       1   TRUE
#>     3:      3    28     6  1.58  1.38       1   TRUE
#>     4:      4    36     6  1.58  1.40       1   TRUE
#>     5:      5    35     6  1.58  1.40       1   TRUE
#>    ---                                              
#> 14396:  14396     0     5  1.58  1.34       1   TRUE
#> 14397:  14397    14     5  1.58  1.34       1   TRUE
#> 14398:  14398    14     5  1.58  1.32       1   TRUE
#> 14399:  14399    20     5  1.58  1.34       1   TRUE
#> 14400:  14400    25     5  1.58  1.34       1   TRUE

# tally up the number of clicks in each species category
table(dat$clicks$species)
#> 
#>      NBHF     Sonar Unclassed 
#>     51590      7452     23595 
```
