# Changelog

## fpod (development version)

- fp_read() now counts POD minutes from 1899-12-30 (the Delphi/Excel
  convention used by the FPOD and CPOD apps), not 1900-01-01. All times
  were previously 2 days late. This change is implemented to stay
  consistent with the FPOD/CPOD apps.
- fp_read() now calculates all times in UTC, and the `tz` argument only
  sets how they are displayed. The default is now `tz = "UTC"`
  (previously `""`, the local time zone). POD clocks have no daylight
  saving time, so reading them in a local time zone could add spurious
  one-hour shifts within a file.
- `env$minute` now starts at 0, matching `clicks$minute`. It previously
  started at 1, so `env` rows were offset by one minute from the clicks.
- `env$pod_on` is now calculated in C++ and follows the FPOD app’s
  logic:
  - FP1/FP3: a minute is on if the minute records on either side of it
    flag it as on, or if it contains clicks.
  - CP1/CP3: a minute is on if the tilt in the minute record that ends
    it is within the pod’s switch angle limits, if the count field of
    the minute record that starts it (CP3 only) is above zero, or if it
    contains clicks.
- fp_summarize() now only counts minutes where the pod was on, and its
  minutes are aligned with click times. They were previously offset by
  one minute and included minutes where the pod was off.
- F-POD battery voltages (`env$bat1v`, `env$bat2v`) are now raw values
  divided by 10 (units of 0.1 V, as in the FPOD app), not by 50.
- C-POD battery columns (`env$bat1v`, `env$bat2v`, `env$bat_use`) are
  now `NA`. C-POD files contain no battery voltages, and these columns
  previously held the raw temperature and tilt values.
- added parameter time_offset to fp_read()
- added a time column to the “env” data.table in the list returned by
  fp_read()

### New features

- fp_read() now also adds a column `env$time_lost`, i.e. the recording
  time missed because the pod maxed out (hit its click limit) in a
  minute.
- fp_read() gains a `time_offset` argument (seconds or difftime), added
  to all times in a file. Use it to convert the POD clock to UTC
  (e.g. -2 hours for a clock set to Central European summer time) and to
  correct known clock errors. A warning is given for plain numbers under
  one hour, which are likely hours given without units.
- fp_read() adds a `time` column to `env`.
- fp_read() adds `header$switch_angle_from` and `header$switch_angle_to`
  for CP1/CP3 files: the pod’s switch angle limits, as raw tilt values.
- fp_read() now gives an error for unknown time zone names, instead of
  silently using UTC”
- fp_summarize() gains an `fpod_compat` argument (default `TRUE`). With
  `fpod_compat = TRUE`, every minute from the first click in `x` onwards
  counts as on, as in the FPOD app, which stops checking a C-POD’s tilt
  once it has seen a click. With `fpod_compat = FALSE`, only minutes
  where the pod was on (`env$pod_on`) count, which excludes minutes
  where the pod was tilted past its switch angle. F-POD results are the
  same either way.

### Bug fixes

- CP1/CP3 files: records of types 251-253 are now skipped instead of
  being read as clicks, and reading stops at the end-of-data record
  (255). The last click of a file is no longer dropped.
- CP1/CP3 files: the minute after the last minute record that the FPOD
  app parses is now treated as on, matching the app.
- C-POD temperatures (`env$degC`) now keep their decimals (raw value /
  5, as in the CPOD app). They were previously rounded to whole degrees.
- fp_summarize(): `bpm` is now `NA` throughout when there is no `buzz`
  column. It was previously `NA` for minutes with clicks and 0 for
  minutes without.
- fp_read() now returns tables that print on the first try after reading
  (they were previously suppressed by data.table after `:=`).

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
