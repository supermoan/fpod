# Finds harbor porpoise feeding buzzes

This function uses one of two methods to classify NBHF clicks into one
of two classes: feeding buzz or non feeding buzz.

## Usage

``` r
fp_find_buzzes(x, method = "clicks", ...)
```

## Arguments

- x:

  a data.table where each row is a click, as the "clicks" element in the
  list object returned by
  [`fp_read()`](https://supermoan.github.io/fpod/reference/fp_read.md).
  Each row must minimally have a POSIXct column `time`, with nanosecond
  precision.

- method:

  the method to use to find feeding buzzes. See details.

- ...:

  Additional arguments passed to specific methods, when relevant. For
  method="threshold", you can pass `threshold=10` to define the maximum
  ICI for a buzz (with values interpreted in units of milliseconds)

## Value

An integer vector of the same length as `nrow(x)`, where the values
indicate that that click (or a sequence of clicks) can be considered a
feeding buzz (value = 1) or not (value = 0).

## Details

Note that the so-called "feeding buzzes" are usually considered to
represent a combination of feeding buzzes and social calls. Even so, the
classifications resulting from all of these methods are commonly used as
a proxy of foraging activity.

The available methods are:

- `clicks` or `pirotta1` method: any inter-click-interval (ICI) less
  than 20 milliseconds is considered a NBHF feeding buzz.

- `trains` or `pirotta2` method: buzzes are identified using a mixture
  Gaussian model, with the number of components k=3. All clicks
  associated with the first component are considered a NBHF feeding
  buzz. This method requires the package `mixtools` to work. Note that
  different implementations of this method sometimes use different units
  for the ICIs (e.g. decimal minutes or milliseconds). The choice of
  units doesn't necessarily change the estimates, but it may affect the
  numerical stability of the computation and lead to
  false/early/non-optimal convergence. Therefore, the `fpod` package
  uses units of milliseconds.

- `sbfi` or `sbfi1` method: the Search Buzz Foraging Identification
  method described in Aofui et al 2026. Requires 3 or more consecutive
  ICIs between 1.25 - 6.65 ms, preceded in the same minute by a
  search/approach click (\< 200 clicks/s). Minute groups are pre-defined
  based on the FPOD starting time.

- `sbfi2` method: as `sbfi`, but with a small refinement. Rather than
  restrict the identification of search-buzzes to pre-defined minute
  groups, this method uses an adaptive minute window. It first
  identifies clusters of buzzes, and then identifies the subset of those
  clusters that are preceded by a search click within 60s (disregarding
  minute chunks). This method is more resilient to edge-cases, where you
  have a search-buzz sequence on either side of a minute (that would
  otherwise be missed with method="sbfi"). This affects absolute buzz
  numbers more than derived estimates such as buzz-positive-minutes. The
  latter isn't necessarily very different between these two variations
  of the SBFI. Note that buzzes for the edge cases always get assigned
  to the later minute.

- `threshold` method: any inter-click-interval (ICI) less than the
  defined threshold is considered a NBHF feeding buzz. The threshold
  must be specified in milliseconds.

## References

Aoufi, S., Rumes, B., Vanaverbeke, J., Degraer, S., & Debusschere, E.
(2026). A Novel Method to Infer Harbor Porpoise Foraging Behavior From
Acoustic Data: A Comparative Assessment Against Established Techniques.
Marine Mammal Science, 42(4), e70292. https://doi.org/10.1111/mms.70292

Pirotta, E., Thompson, P.M., Miller, P.I., Brookes, K.L., Cheney, B.,
Barton, T.R., Graham, I.M. and Lusseau, D. (2014), Scale-dependent
foraging ecology of a marine top predator modelled using passive
acoustic data. Funct Ecol, 28: 206-217.
https://doi.org/10.1111/1365-2435.12146

## Examples

``` r
# first read some FPOD data
fn <- fp_example("gullars_period1.FP3")
dat <- fp_read(fn)

# extract porpoise clicks of quality Hi and Mod
nbhf <- dat$clicks[species == "NBHF" & quality_level >= 2]

# then add a 'feeding buzz' column to the clicks data.table
nbhf$pirotta1 <- fp_find_buzzes(nbhf, method = "clicks")

# using method="clicks" is the equivalent of this:
nbhf$threshold20ms <- fp_find_buzzes(nbhf, method = "threshold", threshold = 20)

# using the gaussian mixture model approach is just as easy:
nbhf$pirotta2 <- fp_find_buzzes(nbhf, method = "pirotta2")
#> number of iterations= 194 

# or we can use one of two variations of the SBFI
nbhf$sbfi <- fp_find_buzzes(nbhf, method = "sbfi")
nbhf$sbfi2 <- fp_find_buzzes(nbhf, method = "sbfi2")

# we can easily compare all of these methods in terms of absolute buzz
# numbers and positive buzz minutes (BPMs)

# first extract only the cols that we need to do this
buzz <- nbhf[, .(minute, pirotta1, threshold20ms, pirotta2, sbfi, sbfi2)]
# define BPMs
bpm <- buzz[, lapply(.SD, function(x) any(x>0)), by = minute][,-1]

# finally, print comparative table
data.frame(
    method = names(bpm),
    tot_clicks = nrow(nbhf),
    tot_buzzes = as.integer(buzz[,lapply(.SD,sum)][,-1]),
    bpm = as.integer(bpm[,lapply(.SD,sum)])
)
#>          method tot_clicks tot_buzzes bpm
#> 1      pirotta1      43216       8962 169
#> 2 threshold20ms      43216       8962 169
#> 3      pirotta2      43216       4752  79
#> 4          sbfi      43216       5204  64
#> 5         sbfi2      43216       5204  64
```
