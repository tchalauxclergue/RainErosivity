#' Rainfall Erosivity Index
#'
#' This function calculates the EI30 (Rainfall Erosivity Index) for each erosive event in a dataset. It uses precipitation data and optionally pre-calculated I30 values to compute the index.
#'
#' @param data A data frame containing the precipitation data.
#' @param precipitation A string specifying the name of the column in `data` that contains the precipitation values.
#' @param event The name of the column in `data` containing event labels.
#' @param temperature A string specifying the name of the column in `data` that contains the temperature values (in Celsius).
#' @param data.I30 Optional: A data frame containing pre-calculated I30 values for each event. If not provided, the function will calculate I30 values.
#' @param I30.event The name of the column in `data.I30` containing event labels.
#' @param I30.label The name of the column in `data.I30` containing I30 values.
#' @param record.step A string representing the time step of the precipitation records in the format "HH:MM:SS". Default is "00:10:00".
#' @param ceiling A logical value indicating whether to use the ceiling function when calculating periods. Default is `FALSE.`
#' @param precip.units A string specifying the units of precipitation. Acceptable values are "mm" (default), "cm", and "m".
#' @param min.temperature A numeric value specifying the minimum temperature required for a precipitation to be considered as snow and not precipitation. Default is 0.
#' @param digits An integer specifying the number of decimal places to round the EI30 values. Default is 0.
#' @param energy.formula A text to choose which formula to use to calculate raindrop energy. "WischmeierSmith1965" is 0.119 + 0.0873 log10(i), "WischmeierSmith1978" is 0.119 + 0.0873 log10(i) with a threshold to 0.283 (rainfall intensity eq. to 76.2 mm h-1), "BrownFoster1987" is 0.29 ( 1 - 0.72 exp(-ir.factor i) ) where *ir.factor* need to be precised
#' @param ir.factor An integer that need to be specified if *energy.formula* is  specifying the value to which the precipitation intensity for each time interval should be multiplicated to. Different values where used: Brown and Foster (1987) = 0.05, RUSLE2 = 0.082 (developed with 15-min precipitation data), Yin et al. (2007) = 1.041 for China, 
#' 
#' @return A data frame with the calculated EI30 values for each erosive event.11
#'
#' @details The function calculates how many times the record step should be multiplied to reach one hour. It then corrects the precipitation units if necessary. For each event, it calculates the rainfall energy and uses pre-calculated or newly calculated I30 values to compute the EI30 index.
#'
#' @references Renard, K. G., & Freimund, J. R. (1994). Using monthly precipitation data to estimate the r-factor in the revised USLE, . 157 , 287–306. URL: https://linkinghub.elsevier.com/retrieve/pii/0022169494901104. doi: 10.1016/0022-1694(94)90110-
#' @references Nearing, M. A., Yin, S., Borrelli, P., & Polyakov, V. O. (2017). Rainfall erosivity: An historical review. CATENA, 157, 357–362. https://doi.org/10.1016/j.catena.2017.06.004
#' @references Yin, S., Nearing, M. A., Borrelli, P., & Xue, X. (2017). Rainfall Erosivity: An Overview of Methodologies and Applications. Vadose Zone Journal, 16(12), 1–16. https://doi.org/10.2136/vzj2017.06.0131
#' @references
#'
#' @author Thomas Chalaux-Clergue
#'
#' @export
event.EI30 <- function(data, precipitation, temperature, event = "Erosive_event", data.I30, I30.event = "Erosive_event", I30.label = "I30_mm.h.1",
                       record.step = "00:10:00", ceiling = FALSE, precip.units = "mm", min.temperature = 0, digits = 0, energy.formula, ir.factor){

  
  if(missing(energy.formula)){
    stop("Please specify 'energy.formula' to choose one formula to calculate rain drop energy.")
  }
  
  # Calculate how many time record step should be multiplied by to reach 1 hour
  b <- as.numeric(substr(record.step, 1, 2))*60 + as.numeric(substr(record.step, 4,5)) + as.numeric(substr(record.step, 7,8))/60

  if(isFALSE(ceiling)){
    period <- base::round(60/b)
  }else{
    period <- base::ceiling(60/b)
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
    dplyr::summarise("EI30_MJ.mm.ha.1.h.1" = NA) %>% # Create a new columns for I30
    dplyr::filter(!is.na(.data[[event]])) %>% # Only keep events and remove the NA row
    ungroup %>% as.data.frame # Correct format

  # Calculate I30 values per event if they are not provided
  if(missing(data.I30)){
    data.I30 <- event.I30(data = data, precipitation = precipitation, temperature = temperature, event = event, record.step = record.step, ceiling = ceiling, precip.units = precip.units, min.temperature = min.temperature)
    I30.event <- colnames(data.I30)[1]
    I30.label <- colnames(data.I30)[2]
  }


  # Calculate the EI30 for each event
  for(e in resu[[event]]){

    if(missing(temperature)){ # No temperature
      p <- data %>% dplyr::filter(.data[[event]] == e) %>% dplyr::select(precipitation) %>% unlist %>% unname # Extract precipitation for this event
    }else{ # With temperature
      p <- data %>% dplyr::filter(.data[[event]] == e & .data[[temperature]] > min.temperature) %>% dplyr::select(precipitation) %>% unlist %>% unname # Extract precipitation for this event
    }

    if(length(p) > 0){
      ervr <- NULL
      for(i in seq_along(p)){
        vr <- p[i] # Volume of precipitation/rainfall (mm) during the time interval r (i.e. `record.step`)
        ir <- p[i] * period # The precipitation/rainfall intensity (mm h^-1) for each time interval r (i.e. `record.step`)
        
        # Precipitation/rainfall energy per unit depth of precipitation/rainfall (MJ ha^-1 mm^-1)
        if(energy.formula == "WischmeierSmith1965"){
          er <- round(0.119 + 0.0873 * log10(ir), 3)
        }else if(energy.formula == "WischmeierSmith1978"){
          er <- round(0.119 + 0.0873 * log10(ir), 3)
          er <- ifelse(er > 0.283, 0.283, er) # threshold eq to 76.2 mm h-1 (Foster et al., 1981) but simplified since for 76.2 mm h-1 er = 0.2832
        }else if (energy.formula == "BrownFoster1987"){
          er <- round(0.29*(1 - 0.72*exp(-ir.factor*ir)), 3) # er = em * ( 1 - a*exp(-b * ir) ) where em is the maximum unit energy as intensity becomes large (fixed to 0.29 according to Rosewell (1986)), a fixed to 0.72 (McGregor and Mutchler, 1976), b fixed to 0.05 (Brown and Foster, 1987)
        }

        ervr <- c(ervr, er*vr) # Rainfall/precipitation energy per volume of rain
      }
      # Calculate the rainfall erosivity index of the event
      resu$EI30_MJ.mm.ha.1.h.1[[which(resu[[event]] == e)]] <- round(sum(ervr, na.rm = TRUE) * data.I30[[I30.label]][which(data.I30[[I30.event]] == e)], digits)
    }else{
      resu$EI30_MJ.mm.ha.1.h.1[[which(resu[[event]] == e)]] <- -1 # to precise that it is a snow event
    }
  }

  return(resu)
}
