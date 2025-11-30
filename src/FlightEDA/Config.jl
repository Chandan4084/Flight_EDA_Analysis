const DEFAULT_CONFIG_PATH = joinpath(@__DIR__, "..", "..", "config", "eda_config.toml")

struct DataConfig
    raw_file::String
    cleaned_file::String
    sample_file::String
end

struct PlotConfig
    dir::String
    scatter_sample_size::Int
    route_min_flights::Int
    delay_lower::Float64
    delay_upper::Float64
end

struct Config
    data::DataConfig
    plots::PlotConfig
    log_level::Logging.LogLevel
end

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
        Float64(get(plot_cfg, "delay_lower", -60.0)),
        Float64(get(plot_cfg, "delay_upper", 180.0)),
    )

    level = log_level_from_string(get(log_cfg, "level", "info"))

    Config(data, plots, level)
end
