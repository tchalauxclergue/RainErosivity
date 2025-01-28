#' Split Precipitation Data into Events
#'
#' This function splits a precipitation dataset into separate events based on specified criteria.
#' An event is defined as a series of precipitation records with no more than a specified delay
#' between them and with a minimum precipitation between events.
#'
#' @param data A data frame containing the precipitation data.
#' @param precipitation A string specifying the name of the column in `data` that contains the precipitation values.
#' @param record.step A string specifying the time step between consecutive records in the format "HH:MM:SS". Default is "00:10:00".
#' @param delay.between.events A string specifying the maximum allowable delay between consecutive precipitation events in the format "HH:MM:SS". Default is "06:00:00".
#' @param min.bw.events A numeric value specifying the minimum precipitation required to separate two events. Default is 1.27 mm.
#' @param ceiling A logical value indicating whether to use the ceiling function when calculating periods. Default is `FALSE`.
#'
#' @details
#' The function labels each precipitation record with an event number, indicating which event it belongs to.
#' An event is considered to have ended if there is a period of time longer than `delay.between.events` with
#' no precipitation or if the sum of precipitation during this period is less than `min.bw.events`.
#'
#' @return A data frame containing the original data with an additional column named "Event" indicating the event number for each record.
#'
#' @examples
#' \dontrun{
#' data <- data.frame(date = seq.POSIXt(from = as.POSIXct("2023-01-01 00:00:00"),
#'                                      to = as.POSIXct("2023-01-02 00:00:00"),
#'                                      by = "10 min"),
#'                    rainfall = c(0, 0.5, 0.2, 0, 0, 0, 0, 0, 0, 0, 2, 3, 0, 0, 1, 0, 0, 0, 1, 0.5, 0))
#' event.splitter(data, precipitation = "rainfall")
#' }
#'
#' @references Meusburger, K., Steel, A., Panagos, P., Montanarella, L., & Alewell, C. (2012). Spatial and temporal variability of rainfall erosivity factor for switzerland, . 16 , 167–177. URL: https://hess.copernicus.org/articles/16/167/2012/. doi:10.5194/hess-16-167-2012.
#'
#' @author Thomas Chalaux-Clergue
#'
#' @export
event.splitter <- function(data, precipitation, record.step = "00:10:00", delay.between.events = "06:00:00", min.bw.events = 1.27, ceiling = FALSE){

  # Set-up
  event.label <- 1 # First event label
  last.precipitation <- -Inf # Index of the last precipitation record initially set as -Inf

  # Create a vector of NA for event labels
  event <- rep(NA, nrow(data))

  # Determine the number of increment needed to cover the delay between two events
  a <- as.numeric(as.numeric(substr(delay.between.events, 1, 2))*60 + as.numeric(substr(delay.between.events, 4,5))) + as.numeric(substr(delay.between.events, 7,8))/60
  b <- as.numeric(substr(record.step, 1, 2))*60 + as.numeric(substr(record.step, 4,5)) + as.numeric(substr(record.step, 7,8))/60

  if(isFALSE(ceiling)){
    period <- base::round(a/b)
  }else{
    period <- base::ceiling(a/b)
  }



  i <- 1
  while(i <= nrow(data)){

    # The step between two element of the vector
    step <- 1

    # If there is precipitation at i
    precip.i <- data[[precipitation]][i]
    if( base::ifelse(base::is.na(precip.i), yes=0, no=precip.i) != 0 ){ # ifelse test helps to remove NA
      event[i] <- event.label # The even label is added at i
      last.precipitation <- i # update last precipitation record

    # If there is NO precipitation at i (i.e. data[[precipitation]][i] == 0)
    }else{
      precip.i <- data[[precipitation]][i - ifelse(i==1, 0, 1)] # precipitation at the index i
      if( base::ifelse(base::is.na(precip.i), yes=0, no=precip.i) != 0 ){ # Verify that the last i position had precipitation recorded

        precip.period <- sum(data[[precipitation]][i:min(i+period, nrow(data))], na.rm = TRUE) # Sum all precipitation from i to the period (or to the last element of the vector)

        # If there is NO precipitation records during the period
        if(precip.period == 0){
          event.label <- event.label + 1 # Update of precipitation Event Label (i.e. new precipitation event)
          step <- period - 1 # New step to skip all the records during the period

        # If there is precipitation records during the period
        }else{
          # New step to skip all null records to the next non null record
          if(all(is.na(data[[precipitation]][(i):(i+period)]))){ # if only NA values on the period
            step <- period - 1
          }else{
            step <- which(data[[precipitation]][(i):(i+period)] != 0)[1] - 1 # the next non null record
          }
          if(precip.period > min.bw.events){
            event[i:(i+step)] <- event.label # Add the current event label to all the indexes between i and the next non null record
            last.precipitation <- i + step # Update the last precipitation record as the next non null record
          }else{
            event.label <- event.label + 1 # Update of precipitation Event Label (i.e. new precipitation event)
          }
        }
      }
    }
    i <- i + step
  }
  return(cbind(data, "Event" = event))
}
