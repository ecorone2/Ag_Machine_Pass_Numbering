Ag Machine Pass Numbering
================
Eric Coronel
August 9, 2018

Purpose of this script
======================

Data collected by agricultural equipment is not user friendly, particularly when within-field data manipulation is needed. It is simple to calculate average yield or fuel usage per field. The challenge is obtaining attributes from individual field passes when there are no identifiers to perform subsettings or groupings.
The code included here uses time difference in seconds between observations to separate machinery passes. The threshold for separating passes can be modified.

Packages needed
---------------

``` r
library(dplyr)
library(ggplot2)
library(rgdal)
```

Importing the seeding shapefile
-------------------------------

A publicly available seeding shapefile can be found at a [Deere website](https://developer.deere.com/#!documentation&doc=.%2Fmyjohndeere%2FfieldOperations.htm&anchor=). The sample seeding shapefile can be downloaded from the following [link](https://developer.deere.com/content/documentation/merriweather_seeding.zip). The zip file needs to be decompressed into a temp file before importing.

``` r
# Download zipfile into tempfile
url <- "https://developer.deere.com/content/documentation/merriweather_seeding.zip"
tmpfn <- tempfile()
zipfile <- download.file(url, tmpfn)
files <- unzip(tmpfn, exdir = tempdir())
```

Once the file is decompressed, it can be imported using `rgdal::readORG`. The `pointDropZ = TRUE` argument is needed because the shapefile has an empty Z column; likely an error during the creation of the file. I created a working copy to avoid manipulating the original file since it takes about 30 seconds to import the original shapefile.

``` r
# Importing the shapefile
seeding_shapefile <- readOGR(dsn = files[4], layer = "Merriweather Farms-JT-01-Corn", pointDropZ = TRUE)
```

    ## OGR data source with driver: ESRI Shapefile 
    ## Source: "C:\Users\EricCoronel\AppData\Local\Temp\RtmpmkAesE\doc\Merriweather Farms-JT-01-Corn.shp", layer: "Merriweather Farms-JT-01-Corn"
    ## with 63761 features
    ## It has 10 fields

``` r
# Working copy
work_copy <- seeding_shapefile
```

First processing
----------------

This step does the following:

-   Creates a datetime variable (later removed).
-   Calculates time difference in seconds among consecutive records (later removed).
-   Creates an indicator variable that assigns 0 if time difference is between 0 to 6 seconds, and 1 to all others (later removed).
-   Calculates the cumulative sum of the indicator variable. Since data are arranged in ascending time order, the cumulative sum of the indicator variable gives us the total number of passes.
-   Creates `pass_factor`, which is `pass_num` formatted as a factor for later visualization.
-   Removes `datetime`, `diff1`, and `indicator` variables.
-   Adds the coordinate variables `coords.x1` and `coords.x2` as part of the attribute table.

``` r
work_copy@data <- work_copy@data %>%
  mutate(datetime = as.POSIXct(Time, format = "%m/%d/%Y %H:%M:%S"),
         diff1 = c(NA, diff(datetime)),
         indicator = ifelse(diff1 %in% c(0:6), 0, 1),
         pass_num = cumsum(indicator),
         pass_factor = as.factor(pass_num)) %>% 
  select(-datetime, -diff1, -indicator) %>% 
  bind_cols(work_copy %>%
              coordinates() %>%
              data.frame)
```

Calculating observations per pass
---------------------------------

Another useful attribute for grouping or subsetting is knowing the number of observations per pass.

``` r
work_copy@data <- work_copy@data %>%
  group_by(pass_num) %>%
  mutate(obs_per_pass = n())
```

Ploting the final version
-------------------------

``` r
# Using a subset for faster display
filter(work_copy@data, pass_num %in% 1:15) %>% 
  ggplot(., aes(x = coords.x1, y = coords.x2, color = pass_factor)) +
  geom_point() +
  scale_color_manual(values = sample(colors(nlevels(work_copy$pass_factor)))) +
  labs(x = "Longitude",
       y = "Latitude",
       color = "Pass Number")
```

![](Process_script_files/figure-markdown_github/plotting-1.png)

``` r
# Plotting the entire shapefile
ggplot(work_copy@data, aes(x = coords.x1, y = coords.x2, color = pass_factor)) +
  geom_point() +
  scale_color_manual(values = sample(colors(nlevels(work_copy$pass_factor)))) +
  labs(x = "Longitude",
       y = "Latitude",
       color = "Pass Number")
```

![](Process_script_files/figure-markdown_github/plotting-2.png)

Exporting the modified shapefile if needed outside of R
-------------------------------------------------------

``` r
writeOGR(obj = work_copy, dsn = ".", layer = "Merriweather-seeding-passes", driver = "ESRI Shapefile")
```

    ## Warning in writeOGR(obj = work_copy, dsn = ".", layer = "Merriweather-
    ## seeding-passes", : Field names abbreviated for ESRI Shapefile driver
