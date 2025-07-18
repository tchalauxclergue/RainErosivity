#' Summarize Erosive Precipitation Events
#'
#' This function identifies and summarizes erosive precipitation events in a dataset, calculating key metrics such as cumulative precipitation, event duration, maximum 30-minute intensity (I30), and Rainfall Erosivity Index (EI30).
#'
#' @param data A data frame containing precipitation data.
#' @param precipitation A string specifying the name of the column in `data` that contains the precipitation values.
#' @param record.step A string specifying the time step between consecutive records in the format "HH:MM:SS". Default is "00:10:00".
#' @param delay.between.event A string specifying the maximum allowable delay between consecutive precipitation events in the format "HH:MM:SS". Default is "06:00:00".
#' @param temperature A string specifying the name of the column in `data` that contains the temperature values (in Celsius).
#' @param Date A string specifying the column name in `data` representing the date and time of each record.
#' @param min.bw.events A numeric value specifying the minimum precipitation required to separate two events. Default is 1.27 mm (Wischemeier and Smith, 1978)
#' @param min.precipitation A numeric value specifying the minimum cumulative precipitation required for an event to be considered erosive. Default is 12.7 (Wishmeier and Smith, 1978)
#' @param ceiling A logical value indicating whether to use the ceiling function when calculating periods. Default is `FALSE`.
#' @param adapt.label A logical value indicating whether to update the event label after filtering by minimum precipitation. Default is `TRUE`.
#' @param precip.units A string specifying the units of precipitation. Acceptable values are "mm" (default), "cm", and "m".
#' @param min.temperature A numeric value indicating the minimum temperature to consider for precipitation (e.g., to exclude snow). Default is 0.
#' @param digits An integer specifying the number of decimal places to round the EI30 values. Default is 0.
#' @param energy.formula A text to choose which formula to use to calculate raindrop energy. "WischmeierSmith1965" is 0.119 + 0.0873 log10(i), "WischmeierSmith1978" is 0.119 + 0.0873 log10(i) with a threshold to 0.283 (rainfall intensity eq. to 76.2 mm h-1), "BrownFoster1987" is 0.29 ( 1 - 0.72 exp(-ir.factor i) ) where *ir.factor* need to be precised
#' @param ir.factor An integer that need to be specified if *energy.formula* is  specifying the value to which the precipitation intensity for each time interval should be multiplicated to. Different values where used: Brown and Foster (1987) = 0.05, RUSLE2 = 0.082 (developed with 15-min precipitation data), Yin et al. (2007) = 1.041 for China, 
#' @param save.dir A optional Connection open for writing the test results data.frame. If "" save the file at working directory.
#' @param note A optional character string to add a note at the end of the file name.
#'
#' @return A data frame summarizing each identified erosive precipitation event, including:
#' \describe{
#'   \item{Event_label}{The label of the event.}
#'   \item{Date_start}{The start date and time of the event.}
#'   \item{Date_end}{The end date and time of the event.}
#'   \item{Duration_min}{The duration of the event in minutes (min).}
#'   \item{Duration_h}{The duration of the event in hours (h).}
#'   \item{Cumulative_precipitation_mm}{The cumulative precipitation of the event in millimeters (mm).}
#'   \item{I30_mm.h.1}{The maximum 30-minute intensity (I30) of the event in mm h^{-1}.}
#'   \item{EI30_MJ.mm.ha.1.h.1}{The Rainfall Erosivity Index (EI30) of the event in MJ mm ha^{-1} h^{-1}.}
#' }
#'
#' @import dplyr
#'
#' @references Wischmeier, W.H., Smith, D.D., 1978. Predicting rainfall erosion losses. A guide to conservation planning. In: Agriculture Handbook No. 537. USDA-SEA, US. Govt. Printing Office, Washington, DC 58 pp.
#' 
#' @author Thomas Chalaux-Clergue
#'
#' @export
event.summary <- function(data, precipitation, record.step = "00:10:00", delay.between.event = "06:00:00", temperature, Date, min.bw.events = 1.27,
                          min.precipitation = 12.7, ceiling = FALSE, adapt.label = TRUE, precip.units = "mm", min.temperature = 0, digits = 0, ir.factor = 0.0873, save.dir, note){

  # Correct precipitation unit
  if(precip.units == "cm"){
    data[[precipitation]] <- data[[precipitation]]/10
  }else if(precip.units == "m"){
    data[[precipitation]] <- data[[precipitation]]/100
  }

  # Identify all precipitation events
  events <- RainErosivity::event.splitter(data = data, precipitation = precipitation, record.step = record.step, delay.between.event = delay.between.event, min.bw.events = min.bw.events, ceiling = ceiling)
  events <- RainErosivity::event.thresholder(data = events, precipitation, event = "Event", min.precipitation = min.precipitation, adapt.label = adapt.label) # Remove precipitation events that are below the minimum precipitation threshold

  # Calculate each event I30
  I30s <- RainErosivity::event.I30(data = events, precipitation = precipitation, temperature = temperature, event = "Erosive_event", record.step = record.step, ceiling = ceiling, precip.units = precip.units, min.temperature = min.temperature)

  # Calculate each event EI30
  EI30s <- RainErosivity::event.EI30(data = events, precipitation = precipitation, event = "Erosive_event", temperature = temperature, data.I30 = I30s, I30.event = colnames(I30s)[1], I30.label = colnames(I30s)[2], record.step = record.step, ceiling = ceiling, precip.units = precip.units, min.temperature = min.temperature, digits = digits, ir.factor = ir.factor)

  # Cumulative precipitation
  cumulative.precip <- events %>%
    dplyr::group_by(Erosive_event) %>% # Group by identified erosive events
    dplyr::filter(!is.na(Erosive_event)) %>% # Only keep events and remove the NA row
    #dplyr::filter(.data[[temperature]] > min.temperature) %>% # remove snow
    dplyr::summarise(Cumulative_precipitation_mm = sum(.data[[precipitation]], na.rm = TRUE)) # Sum event precipitation


  # Event duration
  step.min <- as.numeric(substr(record.step, 1, 2))*60 + as.numeric(substr(record.step, 4,5)) + as.numeric(substr(record.step, 7,8))/60 # Identify the duration of each step

  # Summary table
  event.summary <- events %>%
    dplyr::group_by(Erosive_event) %>% # Group by erosive event
    dplyr::filter(!is.na(Erosive_event)) %>% # Only keep events and remove the NA row
    dplyr::summarise(Event_label = first(Event), # Keep the event label
                     Date_start = first(.data[[Date]]), # The first observation of the event
                     Date_end = last(.data[[Date]]), # The last observation of the event
                     Duration_min = n() * step.min, # Duration of the event in minutes
                     Duration_h = round((n() * step.min)/60, 2) # Duration of the event in secondes
    ) %>% # Add other informations
    dplyr::left_join(y = cumulative.precip, by = dplyr::join_by(Erosive_event)) %>% # Add event cumulative precipitations
    dplyr::left_join(y = I30s, by = dplyr::join_by(Erosive_event)) %>% # Add event I30s
    dplyr::left_join(y = EI30s, by = dplyr::join_by(Erosive_event)) # Add event IE30s


  # save results
  if(!missing(save.dir)){
    file.name <- "Summary_event_erosivity"
    if(!missing(note)){
      file.name <- paste(file.name, note, sep="_")
    }
    utils::write.csv(x = event.summary, file = paste0(save.dir, file.name, ".csv"), row.names = FALSE)
  }

  return(event.summary)
}
