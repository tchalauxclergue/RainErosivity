
<!-- README.md is generated from README.Rmd. Please edit that file -->

# RainErosivity <a href="https://doi.org/10.5281/zenodo.14745960"><img src="man/figures/RainErosivity_logo_ver1_150dpi.png" align="right" height="138" /></a>

<!-- badges: start -->

![GitHub
version](https://img.shields.io/github/r-package/v/tchalauxclergue/RainErosivity?logo=github)
![GitHub Release
Date](https://img.shields.io/github/release-date/tchalauxclergue/RainErosivity?color=blue)
[![DOI](https://zenodo.org/badge/DOI/10.5281/zenodo.1402028.svg)](https://doi.org/10.5281/zenodo.14745960)
[![GitHub
Downloads](https://img.shields.io/github/downloads/tchalauxclergue/RainErosivity/total?label=GitHub%20downloads&style=flat)](https://github.com/tchalauxclergue/RainErosivity/releases)
[![Zenodo
Downloads](https://img.shields.io/badge/Zenodo%20downloads-19-blue)](https://doi.org/10.5281/zenodo.16088184)
![Project Status: Active – The project has reached a stable, usable
state and is being actively
developed.](http://www.repostatus.org/badges/latest/active.svg)
<!-- badges: end -->

# Overview

`RainErosivity` is a comprehensive and freely adjustable R package
designed to identify erosive rainfall events in precipitation records,
calculate rainfall erosivity statistics (I30 (maximum 30 minute rainfall
intensity) and EI30 (rainfall erosivity index)) and summarise rainfall
data (duration and cumulative precipitation).

The `RainErosivity` package is available in this
[Github](https://github.com/tchalauxclergue/RainErosivity) repository
and archived on [Zenodo](https://doi.org/10.5281/zenodo.14745960).

## Key Features

- Splits precipitation records data into rainfall events based on user
  specified thresholds and settings.
- Filters and processes precipitation and erosive rainfall events.
- Computes rainfall erosivity metrics like I30 and EI30.
- Summarises erosive event data over recorded period.

<details>

<summary>

<strong>Table of Contents</strong>
</summary>

- [Installation](#installation)
- [Usages](#usages)
  - [Data preparation](#data-preparation)
  - [Step by step](#step-by-step)
    - [Step 1: Load Data](#step-1-load-data)
    - [Step 2: Identify and label precipitation
      events](#step-2-identify-and-label-precipitation-events)
    - [Step 3: Identify and label erosive
      events](#step-3-identify-and-label-erosive-events)
    - [Step 4: Calculate I30 and EI30
      Metrics](#step-4-calculate-i30-and-ei30-metrics)
  - [All at once: Summarise Erosive
    Events](#all-at-once-summarise-all-erosive-events)
- [Contribution and Getting help](#contribution-and-getting-help)
- [Citation](#citation)

<!-- tocstop -->

<details>


# Installation

``` r
# Install devtools if not already installed
# install.packages(devtools)
library(devtools)

# Install the latest version from GitHub
devtools::install_github("https://github.com/tchalauxclergue/RainErosivity/releases/tag/1.1.0", ref = "master", force = T)

# Alternatively, from the downloaded .tar.gz file
devtools::install_local("path_to_file/RainErosivity_1.1.0.tar.gz", repos = NULL) # 'path_to_file' should be modified accordingly to your working environment
```

# Usages

## Input Data Format

Your input data should be in `.csv` format and include the following
information:

- Timestamp of each observation in hh:mm:ss format.
- Precipitation (mm, cm, etc.).
- Temperature (Celsius (default) or Farenheit).

## Step 1: Load Data

To illustrate the use of the package, precipitation from the Japanese
Meteorological Agency’s (JMA) AMeDAS station in Fukushima City for the
year 2011 is used.

``` r
library(RainErosivity)

# Load your precipitation data

# Get the direction and load to the example precipitation dataset
dir.precip <- system.file("extdata", "JMA_precipitation_Fukushima_2011.csv", package = "RainErosivity")

# Load the csv file
data.precip <- read.csv(dir.precip, sep = ";", na = "", fileEncoding = "latin1")
# data.precip <- read.csv("path-to-your-data/JMA_precipitation_Fukushima_2011.csv") # More common way

data.precip[1:5, c("Date.Time", "Precipitation_mm", "Temperature_C")]
```

    ##          Date.Time Precipitation_mm Temperature_C
    ## 1 01/01/2011 00:20                0           2.5
    ## 2 01/01/2011 00:30                0           1.8
    ## 3 01/01/2011 00:40                0           1.7
    ## 4 01/01/2011 00:50              0.5           1.5
    ## 5 01/01/2011 01:00                0           1.5

``` r
library(dplyr)
```

    ## 
    ## Attache Paket: 'dplyr'

    ## Die folgenden Objekte sind maskiert von 'package:stats':
    ## 
    ##     filter, lag

    ## Die folgenden Objekte sind maskiert von 'package:base':
    ## 
    ##     intersect, setdiff, setequal, union

``` r
# Ensure that precipitation and temperature data are in the right format
data.precip.corr <- data.precip %>%
  dplyr::mutate(
    Precipitation_mm = as.numeric(Precipitation_mm),
    Temperature_C = as.numeric(Temperature_C)
  )
```

    ## Warning: There were 2 warnings in `dplyr::mutate()`.
    ## The first warning was:
    ## ℹ In argument: `Precipitation_mm = as.numeric(Precipitation_mm)`.
    ## Caused by warning:
    ## ! NAs durch Umwandlung erzeugt
    ## ℹ Run `dplyr::last_dplyr_warnings()` to see the 1 remaining warning.

``` r
data.precip.corr[1:5, c("Date.Time", "Precipitation_mm", "Temperature_C")]
```

    ##          Date.Time Precipitation_mm Temperature_C
    ## 1 01/01/2011 00:20              0.0           2.5
    ## 2 01/01/2011 00:30              0.0           1.8
    ## 3 01/01/2011 00:40              0.0           1.7
    ## 4 01/01/2011 00:50              0.5           1.5
    ## 5 01/01/2011 01:00              0.0           1.5

## Step 2: Identify and label precipitation events

The `event.splitter()` function to identify different precipitation
events based on a user defined threshold. The function labels each
precipitation record with an event number, adding a column `Event`,
indicating which event it belongs to (i.e. 1, 2, etc.). The frequency of
precipitation records (`record.step`), the delay between two events
(`delay.between.events`) and the threshold of cumulative precipitation
(in the same unit as precipitation) during the period defined in
`delay.between.event`, below which two events are split, could be freely
defined by the user.

``` r
erosive.events <- RainErosivity::event.splitter(data = data.precip.corr,            # Precipitation data
                                                precipitation = "Precipitation_mm", # The column with precipitation data
                                                record.step = "00:10:00",           # Optional: Record step (default 10 min)
                                                delay.between.events = "06:00:00",  # Optional: Delay between events (default 6 hours)
                                                min.bw.events = 1.27,               # Optional: Minimum of precipitation between events (default 1.27 mm)
                                                # ceiling = FALSE                   # Optional: whether to use the ceiling function when calculating periods. Default is `FALSE`.
                                                )

# An example with the beginning of typhoon Roke (International number ID: 1105) which is the 185th precipitation event in 2011
erosive.events[37438:37448, c("Date.Time", "Precipitation_mm", "Temperature_C", "Event")]
```

    ##              Date.Time Precipitation_mm Temperature_C Event
    ## 37438 19/09/2011 19:20              0.0          18.2    NA
    ## 37439 19/09/2011 19:30              0.0          18.2    NA
    ## 37440 19/09/2011 19:40              0.0          18.3    NA
    ## 37441 19/09/2011 19:50              0.0          18.1    NA
    ## 37442 19/09/2011 20:00              0.5          18.1   185
    ## 37443 19/09/2011 20:10              0.0          18.1   185
    ## 37444 19/09/2011 20:20              0.5          18.1   185
    ## 37445 19/09/2011 20:30              0.5          18.0   185
    ## 37446 19/09/2011 20:40              0.0          18.0   185
    ## 37447 19/09/2011 20:50              1.0          18.1   185
    ## 37448 19/09/2011 21:00              0.5          18.0   185

## Step 3: Identify and label erosive events

The `event.thresholder` function filter out the rainfall events by
applying minimum thresholds for the cumulative precipitation
(`min.precipitation`). The function list the precipitation events that
generate enought cumulative precipitation with an erosive event number,
adding a column `Erosive_event`.

``` r
erosive.events <- RainErosivity::event.thresholder(data = erosive.events,            # Precipitation data
                                                   precipitation = "Precipitation_mm", # The column with precipitation data
                                                   # event = "Event",                  # Optional: The column with the identified events (from event.splitter)
                                                   min.precipitation = 12.7,           # Optional: Minimum of cumulative precipitation (default 12.7 mm)
                                                   # adapt.label = TRUE                # Optional: updates event count when TRUE (default)
                                                   )

# Typhoon Roke is now the 14th erosive event of 2011
erosive.events[37438:37448, c("Date.Time", "Precipitation_mm", "Temperature_C", "Event", "Erosive_event")]
```

    ##              Date.Time Precipitation_mm Temperature_C Event Erosive_event
    ## 37438 19/09/2011 19:20              0.0          18.2    NA            NA
    ## 37439 19/09/2011 19:30              0.0          18.2    NA            NA
    ## 37440 19/09/2011 19:40              0.0          18.3    NA            NA
    ## 37441 19/09/2011 19:50              0.0          18.1    NA            NA
    ## 37442 19/09/2011 20:00              0.5          18.1   185            14
    ## 37443 19/09/2011 20:10              0.0          18.1   185            14
    ## 37444 19/09/2011 20:20              0.5          18.1   185            14
    ## 37445 19/09/2011 20:30              0.5          18.0   185            14
    ## 37446 19/09/2011 20:40              0.0          18.0   185            14
    ## 37447 19/09/2011 20:50              1.0          18.1   185            14
    ## 37448 19/09/2011 21:00              0.5          18.0   185            14

## Step 4: Calculate I30 and EI30 Metrics

The `event.I30` function computes the maximum 30-minute rainfall
intensity (I30). If temperature is available in the record
(`temperature`), the erosion events that occurred during a period when
the temperature was below 0 degrees Celsius (or 32 degrees Fahrenheit)
are considered non-erosive and are indicated by a value of “-1”.

``` r
data.I30 <- RainErosivity::event.I30(data = erosive.events,                # Precipitation data
                                     precipitation = "Precipitation_mm",   # The column with precipitation data
                                     temperature = "Temperature_C",        # Optional but Recommended: The column with temperature data
                                     # event = "Erosive_event",            # Optional: The column with the identified erosive events (from event.thresholder)
                                     # record.step = "00:10:00",           # Optional: Record step (Default 10 min)
                                     # ceiling = FALSE                     # Optional: Whether to use the ceiling function when calculating periods. Default is `FALSE`.
                                     # min.temperature = 0,                # Optional: The minimum temperature below which rainfall is considered as snowfall (Default 0 degree Celsius)
                                     # precip.units = "mm"                 # Optional: To correctly calculate the I30 and label its unit according to the precipitation unit (default: mm)
                                     )

data.I30
```

    ##    Erosive_event I30_mm.h.1
    ## 1              1          7
    ## 2              2          5
    ## 3              3          7
    ## 4              4          6
    ## 5              5          7
    ## 6              6          7
    ## 7              7         24
    ## 8              8         11
    ## 9              9         32
    ## 10            10         18
    ## 11            11         46
    ## 12            12          4
    ## 13            13         46
    ## 14            14         22
    ## 15            15          9
    ## 16            16          7
    ## 17            17          9

The `event.EI30` function computes the erosivity index (EI30)

``` r
data.EI30 <- RainErosivity::event.EI30(data = erosive.events,              # Precipitation data
                                       precipitation = "Precipitation_mm", # The column with precipitation data
                                       temperature = "Temperature_C",      # Optional but Recommended: The column with temperature data
                                       # event = "Erosive_event",          # Optional: The column with the identified erosive events (from event.thresholder)
                                       # data.I30 = data.I30,              # Optional: If already performed with data.I30. Could save time for large dataset.
                                       # I30.event = "Erosive_event",      # Optional: The column containing the label of the event in data.I30
                                       # I30.label = "I30_mm.h.1",         # Optional: The unit of the I30 in data.I30
                                       # record.step = "00:10:00",         # Optional: Record step (Default 10 min)
                                       # ceiling = FALSE,                  # Optional: Whether to use the ceiling function when calculating periods. Default is `FALSE`.
                                       # precip.units = "mm",              # Optional: To correctly calculate the I30 according to the precipitation unit (default: mm)
                                       # min.temperature = 0,              # Optional: The minimum temperature below which rainfall is considered as snowfall (Default 0 degree Celsius)
                                       # digits = 0                        # Optional: Number of digits for the EI30 value
                                       energy.formula = "WischmeierSmith1978", # Formula to calculate raindrop energy among: WischmeierSmith1965, WischmeierSmith1978, and BrownFoster1987
                                       # ir.factor = 0.082,                # An integer that need to be specified if *energy.formula* is specifying the value to which the precipitation intensity for each time interval should be multiplicated to. Different values where used: Brown and Foster (1987) = 0.05, RUSLE2 = 0.082 (developed with 15-min precipitation data), Yin et al. (2007) = 1.041 for China
                                       )

data.EI30
```

    ##    Erosive_event EI30_MJ.mm.ha.1.h.1
    ## 1              1                  29
    ## 2              2                  15
    ## 3              3                  27
    ## 4              4                  16
    ## 5              5                  52
    ## 6              6                  51
    ## 7              7                  94
    ## 8              8                  80
    ## 9              9                 192
    ## 10            10                 100
    ## 11            11                 365
    ## 12            12                  10
    ## 13            13                 288
    ## 14            14                1182
    ## 15            15                  84
    ## 16            16                  21
    ## 17            17                  35

``` r
data.EI30 <- RainErosivity::event.EI30(data = erosive.events,              # Precipitation data
                                       precipitation = "Precipitation_mm", # The column with precipitation data
                                       temperature = "Temperature_C",      # Optional but Recommended: The column with temperature data
                                       # event = "Erosive_event",          # Optional: The column with the identified erosive events (from event.thresholder)
                                       # data.I30 = data.I30,              # Optional: If already performed with data.I30. Could save time for large dataset.
                                       # I30.event = "Erosive_event",      # Optional: The column containing the label of the event in data.I30
                                       # I30.label = "I30_mm.h.1",         # Optional: The unit of the I30 in data.I30
                                       # record.step = "00:10:00",         # Optional: Record step (Default 10 min)
                                       # ceiling = FALSE,                  # Optional: Whether to use the ceiling function when calculating periods. Default is `FALSE`.
                                       # precip.units = "mm",              # Optional: To correctly calculate the I30 according to the precipitation unit (default: mm)
                                       # min.temperature = 0,              # Optional: The minimum temperature below which rainfall is considered as snowfall (Default 0 degree Celsius)
                                       # digits = 0                        # Optional: Number of digits for the EI30 value
                                       energy.formula = "BrownFoster1987", # Formula to calculate raindrop energy among: WischmeierSmith1965, WischmeierSmith1978, and BrownFoster1987
                                       ir.factor = 0.05,                   # An integer that need to be specified if *energy.formula* is specifying the value to which the precipitation intensity for each time interval should be multiplicated to. Different values where used: Brown and Foster (1987) = 0.05, RUSLE2 = 0.082 (developed with 15-min precipitation data), Yin et al. (2007) = 1.041 for China
                                       )

data.EI30
```

    ##    Erosive_event EI30_MJ.mm.ha.1.h.1
    ## 1              1                  21
    ## 2              2                  10
    ## 3              3                  19
    ## 4              4                  11
    ## 5              5                  37
    ## 6              6                  36
    ## 7              7                  89
    ## 8              8                  60
    ## 9              9                 179
    ## 10            10                  83
    ## 11            11                 359
    ## 12            12                   7
    ## 13            13                 287
    ## 14            14                 914
    ## 15            15                  61
    ## 16            16                  15
    ## 17            17                  26

``` r
data.EI30 <- RainErosivity::event.EI30(data = erosive.events,              # Precipitation data
                                       precipitation = "Precipitation_mm", # The column with precipitation data
                                       temperature = "Temperature_C",      # Optional but Recommended: The column with temperature data
                                       # event = "Erosive_event",          # Optional: The column with the identified erosive events (from event.thresholder)
                                       # data.I30 = data.I30,              # Optional: If already performed with data.I30. Could save time for large dataset.
                                       # I30.event = "Erosive_event",      # Optional: The column containing the label of the event in data.I30
                                       # I30.label = "I30_mm.h.1",         # Optional: The unit of the I30 in data.I30
                                       # record.step = "00:10:00",         # Optional: Record step (Default 10 min)
                                       # ceiling = FALSE,                  # Optional: Whether to use the ceiling function when calculating periods. Default is `FALSE`.
                                       # precip.units = "mm",              # Optional: To correctly calculate the I30 according to the precipitation unit (default: mm)
                                       # min.temperature = 0,              # Optional: The minimum temperature below which rainfall is considered as snowfall (Default 0 degree Celsius)
                                       # digits = 0                        # Optional: Number of digits for the EI30 value
                                       energy.formula = "BrownFoster1987", # Formula to calculate raindrop energy among: WischmeierSmith1965, WischmeierSmith1978, and BrownFoster1987
                                       ir.factor = 0.082,                   # An integer that need to be specified if *energy.formula* is specifying the value to which the precipitation intensity for each time interval should be multiplicated to. Different values where used: Brown and Foster (1987) = 0.05, RUSLE2 = 0.082 (developed with 15-min precipitation data), Yin et al. (2007) = 1.041 for China
                                       )

data.EI30
```

    ##    Erosive_event EI30_MJ.mm.ha.1.h.1
    ## 1              1                  24
    ## 2              2                  12
    ## 3              3                  23
    ## 4              4                  13
    ## 5              5                  43
    ## 6              6                  41
    ## 7              7                 102
    ## 8              8                  71
    ## 9              9                 196
    ## 10            10                  98
    ## 11            11                 386
    ## 12            12                   8
    ## 13            13                 294
    ## 14            14                1091
    ## 15            15                  72
    ## 16            16                  18
    ## 17            17                  30

## All at once: Summarise All Erosive events

The `event.summary` function performs all the steps described above and
summarise all the events that occurred during the period. The starting
and ending date and time, duration in minutes and hours, the cumulative
precipitation, I30 and EI30.

``` r
all.events <- RainErosivity::event.summary(data = data.precip.corr,            # Precipitation data
                                           precipitation = "Precipitation_mm", # The column with precipitation data
                                           # record.step = "00:10:00",         # Optional: Record step (default 10 min)
                                           # delay.between.event = "06:00:00", # Optional: Delay between events (default 6 hours)
                                           temperature = "Temperature_C",      # Optional but Recommended: The column with temperature data
                                           Date = "Date.Time",                 # The column with date and time data
                                           # min.bw.events = 1.27,             # Optional: Minimum of precipitation between events (default 1.27 mm)
                                           # min.precipitation = 12.7,         # Optional: Minimum of cumulative precipitation (default 12.7 mm)
                                           # ceiling = FALSE,                  # Optional: whether to use the ceiling function when calculating periods. Default is `FALSE`.
                                           # adapt.label = TRUE,               # Optional: updates event count when TRUE (default)
                                           # precip.units = "mm",              # Optional: To correctly calculate the I30 according to the precipitation unit (default: mm)
                                           # min.temperature = 0               # Optional: The minimum temperature below which rainfall is considered as snowfall (default 0 degree Celsius)
                                           # digits = 0,                       # Optional: Number of digits for the EI30 value (default 0)
                                           energy.formula = "BrownFoster1987", # Formula to calculate raindrop energy among: WischmeierSmith1965, WischmeierSmith1978, and BrownFoster1987
                                           ir.factor = 0.082,                   # An integer that need to be specified if *energy.formula* is specifying the value to which the precipitation intensity for each time interval should be multiplicated to.
                                           # save.dir = dir.example,           # Optional: Directory path for saving the results
                                           # note = "example"                  # Optional: Additional note to append to the file name
                                           )
                                       
all.events
```

    ## # A tibble: 17 × 9
    ##    Erosive_event Event_label Date_start       Date_end   Duration_min Duration_h
    ##            <int>       <dbl> <chr>            <chr>             <dbl>      <dbl>
    ##  1             1          40 18/02/2011 02:00 18/02/201…          340       5.67
    ##  2             2          75 19/04/2011 03:50 19/04/201…          870      14.5 
    ##  3             3          78 23/04/2011 04:40 23/04/201…          510       8.5 
    ##  4             4          91 12/05/2011 17:50 40676               380       6.33
    ##  5             5          95 29/05/2011 11:40 30/05/201…         1940      32.3 
    ##  6             6         116 26/06/2011 07:10 27/06/201…         2070      34.5 
    ##  7             7         126 09/07/2011 15:30 09/07/201…           70       1.17
    ##  8             8         141 27/07/2011 16:50 28/07/201…          970      16.2 
    ##  9             9         142 28/07/2011 16:50 28/07/201…          150       2.5 
    ## 10            10         143 29/07/2011 04:40 29/07/201…          350       5.83
    ## 11            11         156 15/08/2011 16:20 15/08/201…           50       0.83
    ## 12            12         161 21/08/2011 02:30 21/08/201…          800      13.3 
    ## 13            13         181 10/09/2011 17:30 10/09/201…           30       0.5 
    ## 14            14         185 19/09/2011 20:00 21/09/201…         3000      50   
    ## 15            15         190 05/10/2011 13:20 06/10/201…         1010      16.8 
    ## 16            16         198 22/10/2011 03:50 22/10/201…          530       8.83
    ## 17            17         231 03/12/2011 07:00 03/12/201…          510       8.5 
    ## # ℹ 3 more variables: Cumulative_precipitation_mm <dbl>, I30_mm.h.1 <dbl>,
    ## #   EI30_MJ.mm.ha.1.h.1 <dbl>

# Contribution and Getting help

Contributions, bug reports, and feature requests are welcome! Feel free
to submit a pull request or open an issue on the repository.

If you encounter a clear bug, please file and issue or send an email to
[Thomas Chalaux-Clergue](mailto:thomaschalaux@icloud.com).

# Citation

To cite this packages:

``` r
utils::citation(package = "RainErosivity")
```

    ## To cite the 'RainErosivity' package in publications please use:
    ## 
    ##   Chalaux-Clergue, T. (2025). RainErosivity: A tool for calculating the
    ##   Rainfall Erosivity Index of precipitation events, Zenodo [Package]:
    ##   https://doi.org/10.5281/zenodo.14745960, Github [Package]:
    ##   https://github.com/tchalauxclergue/RainErosivity, Version = 1.1.0.
    ## 
    ## Ein BibTeX-Eintrag für LaTeX-Benutzer ist
    ## 
    ##   @Manual{,
    ##     title = {RainErosivity: Customisable Tools to Calculate Precipitation Event Rainfall Erosivity Index},
    ##     author = {{Chalaux-Clergue} and {Thomas}},
    ##     year = {2025},
    ##     month = {7},
    ##     note = {R package version 1.1.0},
    ##     doi = {https://doi.org/10.5281/zenodo.14745960},
    ##     url = {https://github.com/tchalauxclergue/RainErosivity},
    ##   }
