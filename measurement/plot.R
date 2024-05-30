#!/usr/bin/Rscript

library(ggplot2)
library(rjson)


read_trace <- function(device_name, option_name) {
  # Read the CSV file
  trace_file <-
    sprintf("%s/%s/%s_trace.pcap.csv", data_folder, device_name, option_name)
  trace <- read.csv(trace_file, header = FALSE)

  colnames(trace) <- c("unix", "throughput")
  trace$throughput <- trace$throughput / 1024 / 1024
  trace$elapsed <- trace$unix - trace$unix[1] + settings$seconds_before_parts

  return(trace)
}

read_cpu_load <- function(device_name, option_name) {
  cpu_stats_file <-
    sprintf("%s/%s/%s_cpu_load.csv", data_folder, device_name, option_name)
  cpu_stats <- read.csv(cpu_stats_file)

  cpu_count <- length(unique(cpu_stats$cpu))
  cpu_load <- data.frame(unix = unique(cpu_stats$unix))
  cpu_load$elapsed <- cpu_load$unix - cpu_load$unix[1]

  for (i in seq(nrow(cpu_stats) / cpu_count)) {
    for (j in seq(cpu_count)) {
      index <- (i - 1) * cpu_count + j

      cpu_load[i, paste0("cpu", j - 1)] <-
        100 - cpu_stats[index, "idle"] - cpu_stats[index, "iowait"]
    }
  }

  return(list("count" = cpu_count, "load" = cpu_load))
}

calc_throughput_stats <- function(parts, plot_data) {
  for (part in seq_len(nrow(parts))) {
    values <- plot_data$elapsed >= parts$start[part] &
      plot_data$elapsed < parts$end[part]

    throughput <- plot_data[values, "throughput"]
    parts$mean[part]   <- mean(throughput)
    parts$median[part] <- median(throughput)
  }

  return(parts)
}

plot <- function(device_name, device_option, plot_data, parts, cpu_count) {
  col_pal <- scales::hue_pal()(2)

  y_max <- 1030
  sec_axis_scale <- 0.1

  title <- "Firewall iperf3 comparison"
  title <- sprintf("%s: %s - %s", title, device_name, device_option)

  cpu_legend <- "CPU Load"
  if (cpu_count > 1)
    cpu_legend <- paste(cpu_legend, sprintf("(%d Cores)", cpu_count))


  # Function for plotting the data
  plot <- ggplot(plot_data, aes(x = elapsed)) +
    geom_vline(xintercept = c(0, parts$start, parts$end),
               linetype = "dashed", color = "black")

  for (i in seq(cpu_count)) {
    plot <- plot +
      geom_point(y = plot_data[, paste0("cpu", i - 1)] / sec_axis_scale,
                 color = col_pal[2], alpha = 1 / cpu_count,
                 aes(shape = "Values"))
  }

  plot <- plot +
    geom_point(aes(y = throughput, color = "Values")) +

    geom_segment(data = parts, linetype = "solid",
                 aes(x = start, xend = end,
                     y = mean, yend = mean, color = "Mean")) +

    geom_segment(data = parts, linetype = "dashed",
                 aes(x = start, xend = end,
                     y = median, yend = median, color = "Median")) +

    scale_x_continuous(n.breaks = 10) +
    scale_y_continuous(n.breaks = 10, limits = c(0, y_max),
                       sec.axis = sec_axis(
                         name = "CPU load [%]",
                         transform = ~. * sec_axis_scale,
                         breaks = seq(0, 100, 10)
                       )) +

    scale_color_manual("Throughput", breaks = c("Values", "Mean", "Median"),
                       values = c(col_pal[1], "black", "black")) +
    scale_shape_discrete(cpu_legend) +

    annotate("text", x = parts$label_x, y = y_max, label = parts$label_text) +
    ggtitle(title) + xlab("Duration [s]") + ylab("Throughput [Mbit/s]") +
    theme(legend.position = "bottom") +

    guides(color = guide_legend(override.aes = list(
      linetype = c("blank", "solid", "dashed"),
      shape = c(16, NA, NA)
    )))

  print(plot)
}

calc_parts <- function() {
  parts <- data.frame()
  end <- 0

  for (part in settings$parts) {
    if (part$disabled) next

    start <- end   + settings$seconds_before_parts
    end   <- start + settings$seconds_per_part

    parts <- rbind(parts, data.frame(
      start = start, end = end,
      label_x = start + settings$seconds_per_part / 2,
      label_text = part$name
    ))
  }

  return(parts)
}


data_folder <- commandArgs(trailingOnly = TRUE)[1]

# Read the JSON file
settings_file <- sprintf("%s/settings.json", data_folder)
settings <- fromJSON(file = settings_file)

parts <- calc_parts()

for (device in settings$devices) {
  if (device$disabled) next

  for (option in settings$options) {
    if (option$disabled) next

    trace <- read_trace(device$name, option$name)
    cpu <- read_cpu_load(device$name, option$name)

    plot_data <- merge(trace, cpu$load, by = "elapsed", all = TRUE)
    throughput_stats <- calc_throughput_stats(parts, plot_data)

    plot(device$name, option$name, plot_data, throughput_stats, cpu$count)
  }
}
