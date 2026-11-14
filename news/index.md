# Changelog

## fpod 1.1.0

CRAN release: 2026-11-07

- several improvements and extensions to fp_find_buzzes():
- added alias “pirotta1” for method = “clicks”
- added alias “pirotta2” for method = = “trains”
- added two variants of the Search Buzz Feeding Identification (SBFI)
  method to fp_find_buzzes(), “sfbi1” and “sfbi2”
- added method “threshold” to fp_find_buzzes(), to facilitate the use of
  custom thresholds for identifying buzzes.
- refactored fp_find_buzzes() to use ICIs in units of ms (rather than
  decimal minutes with nanosecond precision). This improves the
  numerical stability of method=“pirotta2”
- added some more examples for fp_find_buzzes()

## fpod 1.0.2

CRAN release: 2026-09-14

- fp_read() now handles empty FP3 files better to avoid crashing when
  reading multiple FP3 files.

## fpod 1.0.1

CRAN release: 2026-05-12

- add () behind function names in package description.

## fpod v1.0.0 (development version)

- Initial CRAN submission.
