# fpod
R package that enables directly loading FPOD and CPOD data files into R

# Features
There really is only one feature in this package: reading FPOD and CPOD data into R directly from the FPOD data files (i.e. the .CP1, .CP3, .FP1 and .FP3 files). The FPOD data files contain binary data, so they can't trivially be read into R using the usual approach (e.g. fread or read.csv). This package decodes the binary data and imports all the data in one go (i.e. header/metadata, clicks, KERNO classifications, environmental data and pseudo-WAV data). It is then trivial to aggregate data as you please, e.g. DPMs per time block. The advantage of handling data processing in R is a long topic, but suffice it to say that it 1) simplifies things (many fewer steps, as different vars have to be exported in multiple goes in the official FPOD app), and more importantly, 2) makes data processing 100% transparent and reproducible.

Note that at the time of writing, the fpod R package has only partial support for CPOD files - that is to say, it can only import click and classification data, but not environmental & wav data. I plan to add this in the future.

# Suggested workflow
1. Use the official FPOD app to import FPOD data from a FPOD memory card (this generates a FP1 file)
2. Use the FPOD app to run the KERNO classifier (this generates a FP3 file)
3. Use the FPOD R package (this package) to read the FP3 file data into R
4. Run your data processing and analyses in R

# Installation 
The simplest way to install the fpod package is by using devtools::install_github, as outlined below.

```
install.packages("devtools")
library(devtools)
install_github("supermoan/fpod")
```

# Usage
Some basic examples are provided below. See `?read_fpod` for details.
``` r
library(fpod)

# read a FP3 file
dat <- read_fpod(file = "some_site period1 2026 01 10.FP3")

# show misc. information (pod number, deployment date, etc.)
dat$header

# tally up the number of clicks in each species category
table(dat$clicks$species)

# Calculate Detection Positive Minutes (DPMs) for porpoises per day
dpm_per_day <- dat$clicks[species=="NBHF", length(unique(minute(time))), as.Date(time)]
```

# Disclaimer
Note that this project is not affiliated with the manufacturer of the CPOD and FPOD ([Chelonia](https://www.chelonia.co.uk/)). 



