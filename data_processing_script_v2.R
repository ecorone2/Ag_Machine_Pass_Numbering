
# Packages needed

library(dplyr)
library(ggplot2)
library(rgdal)

# Importing original shapefile
seeding_shapefile <- readOGR(dsn = "C:/Users/EricCoronel/Documents/various_DS_projects/Ag_Machine_Pass_Numbering/seeding_shapefile", layer = "Merriweather Farms-JT-01-Corn", pointDropZ = TRUE)

# Creating a working copy
work_copy <- seeding_shapefile

# Creating a datetime variable 
# Calculating difference between consecutive records (in seconds)
# Creating an indicator variable that assigns 0 if difference is between 0 to 6 seconds, and 1 to others
# Since data are arranged in ascending time order, the cumulative sum of the indicator variable gives us 
# the number of passes
work_copy@data <- work_copy@data %>%
  mutate(datetime = as.POSIXct(Time, format = "%m/%d/%Y %H:%M:%S"),
         diff1 = c(NA, diff(datetime)),
         indicator = ifelse(diff1 %in% c(0:6), 0, 1),
         pass_num = cumsum(indicator))

# Calculating number obs per pass
# Creating a random order of pass numbers for later display (also made a factor)
obs_pass <- work_copy@data %>%
  group_by(pass_num) %>%
  summarize(obs_per_pass = n()) %>%
  mutate(pass_scramble = factor(sample(pass_num)))

# Joining previous dataframe to shapefile
# Removing datetime, diff1, and indicator variables
# Making actual pass numbers a factor
work_copy@data <- work_copy@data %>%
  left_join(obs_pass, by = "pass_num") %>%
  select(-datetime, -diff1, -indicator) %>%
  mutate(pass_factor = factor(pass_num))

# Creating a dataframe with the coordinates
xycoords <- work_copy %>%
  coordinates() %>%
  data.frame

# Joining the coordinates with the shapefile
work_copy@data <- work_copy@data %>%
  bind_cols(xycoords)

# Plot to view final result
# Pass_scramble is used for coloring to help with visualization
# Using a subset for faster display
ggplot(filter(work_copy@data, pass_num %in% c(21:25)), 
       aes(x = coords.x1, y = coords.x2, color = pass_scramble)) +
  geom_point() +
  labs(color = "Passes \n (order was randomized)")

# Plotting the entire shapefile
ggplot(work_copy@data, aes(x = coords.x1, y = coords.x2, color = pass_scramble)) +
  geom_point() +
  scale_color_hue(h = c(0, 360), c = 100, l = c(30, 60)) +
  labs(x = "Longitude",
       y = "Latitude",
       color = "Passes \n (order was randomized)")

# Export new shapefile if needed
writeOGR(obj = work_copy, dsn = ".", layer = "Merriweather-seeding-v2", driver = "ESRI Shapefile")

# Remove extra files
rm(obs_pass, xycoords, a)
