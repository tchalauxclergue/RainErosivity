#' Calculate the Maximum 30-Minute Intensity for Erosive Events
#'
#' This function calculates the maximum 30-minute precipitation intensity (I30) for each erosive event in a dataset.
#'
#' @param data A data frame containing the precipitation data.
#' @param precipitation A string specifying the name of the column in `data` that contains the precipitation values.
#' @param temperature A string specifying the name of the column in `data` that contains the temperature values (in Celsius).
#' @param events A string specifying the name of the column in `data` that contains the erosive event labels. Default is "Erosive_Event".
#' @param record.step A string specifying the time step between records in the format "HH:MM:SS". Default is "00:10:30".
#' @param ceiling A logical value indicating whether to use the ceiling function when calculating periods. Default is `FALSE`.
#' @param precip.units A string specifying the units of precipitation. Acceptable values are "mm" (default), "cm", and "m".
#' @param min.temperature A numeric value specifying the minimum temperature required for a precipitation to be considered as snow and not precipitation. Default is 0.
#'
#' @details
#' The function calculates the maximum 30-minute precipitation intensity (I30) for each erosive event in the dataset. The time step between records is specified by `record.step`, and the units of precipitation can be specified using `precip.units`.
#' If `ceiling` is TRUE, the ceiling function is used to calculate the number of periods needed for 30 minutes; otherwise, the round function is used.
#'
#' @return A data frame with columns for the event labels and the corresponding maximum 30-minute precipitation intensity (I30) in mm/h.
#'
#' @examples
#' \dontrun{
#' data <- data.frame(date = seq.POSIXt(from = as.POSIXct("2023-01-01 00:00:00"),
#'                                      to = as.POSIXct("2023-01-01 03:30:00"),
#'                                      by = "10 min"),
#'                    rainfall = c(0, 0.5, 0.2, 0.1, 0, 0, 0, 0, 0, 0, 0, 2, 3, 0, 0, 1, 0, 0, 0, 0, 0, 0),
#'                    Event = c(NA, 1, 1, 1, NA, NA, NA, NA, NA, NA, NA, 2, 2, 2, 2, 2, NA, NA, NA, NA, NA, NA)
#'                    Erosive_Event = c(NA, NA, NA, NA, NA, NA, NA, NA, NA, NA, NA, 1, 1, 1, 1, 1, NA, NA, NA, NA, NA, NA))
#' event.I30(data, precipitation = "rainfall")
#' }
#'
#' @import dplyr
#'
#' @references Renard, K. G., & Freimund, J. R. (). Using monthly precipitation data to estimate the r-factor in the revised USLE, . 157 , 287–306. URL: https://linkinghub.elsevier.com/retrieve/pii/0022169494901104. doi:10.1016/0022-1694(94)90110-
#'
#' @author Thomas Chalaux-Clergue
#'
#' @export
event.I30 <- function(data, precipitation, temperature, event = "Erosive_event", record.step = "00:10:00", ceiling = FALSE, min.temperature = 0, precip.units = "mm"){

  require(dplyr)

  # Calculate the period (i.e. number of indices) needed to consider 30 minutes
  b <- as.numeric(substr(record.step, 1, 2))*60 + as.numeric(substr(record.step, 4,5)) + as.numeric(substr(record.step, 7,8))/60

  if(isFALSE(ceiling)){
    period <- trunc(base::round(30/b) /2)
  }else{
    period <- trunc(base::ceiling(30/b)/2)
  }

  # Correct precipitation unit
  if(precip.units == "cm"){
    data[[precipitation]] <- data[[precipitation]]/10
  }else if(precip.units == "m"){
    data[[precipitation]] <- data[[precipitation]]/100
  }

  # Generate the result data frame for each erosive event
  resu <- data %>%
    group_by(.data[[event]]) %>% # Group per erosive event
    dplyr::summarise("I30_mm.h.1" = NA) %>% # Create a new columns for I30
    dplyr::filter(!is.na(.data[[event]])) %>% # Only keep events and remove the NA row
    ungroup %>% as.data.frame # Correct format

  # Calculate the I30 for each event
  for(e in resu[[event]]){
    if(missing(temperature)){ # No temperature
      p <- data %>% dplyr::filter(.data[[event]] == e) %>% dplyr::select(precipitation) %>% unlist %>% unname # Extract precipitation for this event
    }else{ # With temperature
      p <- data %>% dplyr::filter(.data[[event]] == e & .data[[temperature]] > min.temperature) %>% dplyr::select(precipitation) %>% unlist %>% unname # Extract precipitation for this event
    }

    if(length(p) > 1+period){ # if there is at least enough information to do one window
      i30 <- NULL
      for(i in (1+period):(length(p)-period)){ # move the window during the event
        i30 <- c(i30, sum(p[(i-period):(i+period)], na.rm = TRUE)*2) # calculate the sum of precipitation during 30 mins then multiply it by 2 -> mm/h
      }
      resu$I30_mm.h.1[which(resu[[event]] == e)] <- max(i30) # Add the higher i30 for the event
    }else{
      resu$I30_mm.h.1[which(resu[[event]] == e)] <- -1 # Precise that there is no I30 because of the snow
    }

  }

  return(resu)
}
