#' Filter Erosive Precipitation Events
#'
#' This function identifies and labels precipitation events that exceed a specified minimum cumulative precipitation threshold.
#'
#' @param data A data frame containing the precipitation data.
#' @param precipitation A string specifying the name of the column in `data` that contains the precipitation values.
#' @param events A string specifying the name of the column in `data` that contains the event labels. Default is "Events".
#' @param min.precipitation A numeric value specifying the minimum cumulative precipitation required for an event to be considered erosive. Default is 12.7.
#' @param adapt.label A logical value indicating whether to update the event label after filtering by minimum precipitation. Default is `TRUE`.
#'
#' @details
#' The function filters precipitation events based on the cumulative precipitation threshold and labels the events that exceed this threshold.
#' If `adapt.label` is TRUE, the identified events will be re-labelled in sequential order. Otherwise, the original event labels are retained.
#'
#' @return A data frame containing the original data with an additional column named "Erosive_events" indicating the erosive event number for each record.
#'
#' @examples
#' \dontrun{
#' data <- data.frame(date = seq.POSIXt(from = as.POSIXct("2023-01-01 00:00:00"),
#'                                      to = as.POSIXct("2023-01-01 03:30:00"),
#'                                      by = "10 min"),
#'                    rainfall = c(0, 1.5, 2.2, 2, 0, 0, 0, 0, 0, 0, 0, 2, 3, 0, 0, 1, 0, 0, 0, 0, 0, 0),
#'                    Event = c(NA, 1, 1, 1, NA, NA, NA, NA, NA, NA, NA, 2, 2, 2, 2, 2, NA, NA, NA, NA, NA, NA))
#' event.thresholder(data, precipitation = "rainfall")
#' }
#'
#' @import dplyr
#'
#' @references Meusburger, K., Steel, A., Panagos, P., Montanarella, L., & Alewell, C. (2012). Spatial and temporal variability of rainfall erosivity factor for switzerland, . 16 , 167–177. URL: https://hess.copernicus.org/articles/16/167/2012/. doi:10.5194/hess-16-167-2012.
#'
#' @author Thomas Chalaux-Clergue
#'
#' @export
event.thresholder <- function(data, precipitation, event = "Event", min.precipitation = 12.7, adapt.label = TRUE){

  require(dplyr)

  # Extract the event labels
  ev <- data %>%
    dplyr::group_by(.data[[event]]) %>% # Group precipitation per event label
    dplyr::summarise(cumulative.precip = base::sum(.data[[precipitation]], na.rm = TRUE)) %>% # Calculate the sum of precipitation for each event
    dplyr::filter(!is.na(.data[[event]])) %>% # Only keep events and remove the NA row
    dplyr::filter(cumulative.precip >= min.precipitation) %>% # Remove events with cumulative precipitation lower than min.precipitation
    dplyr::select(Event) %>% unlist %>% unname # Only keep the labels of event above the min.precipitation threshold

  # Initiate the column where event above the threshold are identified
  data$Erosive_event <- NA

  # For each precipitation event that is above the threshold
  for(i in seq_along(ev)){
    # If the user want to keep the initial event label
    if(isFALSE(adapt.label)){ # Yes: adapt.label = FALSE
      event.label <- ev[i]
    }else{ # If the user want to update the event label (i.e. adapt.label = FALSE)
      event.label <- i # The event label is its new position
    }
    # Add the label at every position of this event
    data[which(data[[event]] == ev[i]), "Erosive_event"] <- event.label
  }
  return(data)
}
