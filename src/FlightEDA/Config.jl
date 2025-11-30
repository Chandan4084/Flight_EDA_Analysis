# This is the default path to the configuration file.
const DEFAULT_CONFIG_PATH = joinpath(@__DIR__, "..", "..", "config", "eda_config.toml")

# This structure holds the configuration settings related to data files.
struct DataConfig
    raw_file::String # Path to the raw data file
    cleaned_file::String # Path to the cleaned data file
    sample_file::String # Path to the sample data file
end

# This structure holds the configuration settings for generating plots.
struct PlotConfig
    dir::String # Directory to save the plots
    scatter_sample_size::Int # Number of samples to use for scatter plots
    route_min_flights::Int # Minimum number of flights for a route to be included in plots
    route_top_n::Int # Number of worst routes to display
    delay_lower::Float64 # Lower bound for delay plots
    delay_upper::Float64 # Upper bound for delay plots
end

# This is the main configuration structure.
# It holds all the other configuration structures.
struct Config
    data::DataConfig # Data-related configuration
    plots::PlotConfig # Plot-related configuration
    log_level::Logging.LogLevel # Logging level for the application
end

# This is a list of the columns that are required to be in the dataset.
const REQUIRED_COLUMNS = [
    :fl_date,
    :arr_delay,
    :dep_delay,
    :distance,
    :crs_dep_time,
    :op_unique_carrier,
    :origin,
    :dest,
    :cancelled,
    :cancellation_code,
    :carrier_delay,
    :weather_delay,
    :nas_delay,
    :security_delay,
    :late_aircraft_delay,
]

# This function converts a string representation of a log level
# to a valid LogLevel object.
log_level_from_string(level::AbstractString) = begin
    lower = lowercase(level)
    if lower in ["debug"]
        Logging.Debug
    elseif lower in ["info"]
        Logging.Info
    elseif lower in ["warn", "warning"]
        Logging.Warn
    elseif lower in ["error"]
        Logging.Error
    else
        Logging.Info
    end
end

# This function loads the configuration from a TOML file.
# If no path is provided, it uses the default path.
function load_config(path::String=DEFAULT_CONFIG_PATH)
    isfile(path) || error("Config file not found: $path")
    cfg = TOML.parsefile(path)

    data_cfg = get(cfg, "data", Dict{String, Any}())
    plot_cfg = get(cfg, "plots", Dict{String, Any}())
    log_cfg = get(cfg, "logging", Dict{String, Any}())

    data = DataConfig(
        get(data_cfg, "raw_file", "data/flight_data_2024.csv"),
        get(data_cfg, "cleaned_file", "data/flight_data_2024_cleaned.csv"),
        get(data_cfg, "sample_file", "data/flight_data_2024_sample.csv"),
    )

    plots = PlotConfig(
        get(plot_cfg, "dir", "plots"),
        get(plot_cfg, "scatter_sample_size", 20_000),
        get(plot_cfg, "route_min_flights", 100),
        get(plot_cfg, "route_top_n", 10),
        Float64(get(plot_cfg, "delay_lower", -60.0)),
        Float64(get(plot_cfg, "delay_upper", 180.0)),
    )

    level = log_level_from_string(get(log_cfg, "level", "info"))

    Config(data, plots, level)
end
