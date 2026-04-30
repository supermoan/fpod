# Get path to fpod example

Get path to fpod example

## Usage

``` r
fp_example(path = NULL)
```

## Arguments

- path:

  Name of the file. If NULL, all example files are listed.

## Value

A character vector, containing the path(s) that matched, or the empty
string, "", if none matched.

## Examples

``` r
# get a list all example files
fp_example()
#> [1] "gullars_period1.FP3"

# get the path for this particular file
fp_example("gullars_period1.FP3")
#> [1] "/home/runner/work/_temp/Library/fpod/extdata/gullars_period1.FP3"
```
