module FlightEDA

using CSV
using DataFrames
using Dates
using Logging
using Random
using Statistics
using TOML
using Plots
using StatsPlots

include("FlightEDA/Config.jl")
include("FlightEDA/Utils.jl")
include("FlightEDA/Plotting.jl")
include("FlightEDA/Smoke.jl")
include("FlightEDA/Phases.jl")
include("FlightEDA/CLI.jl")

export DEFAULT_CONFIG_PATH,
       Config, DataConfig, PlotConfig,
        load_config,
        load_raw_dataset, clean_and_engineer_data,
        run_load_phase, run_clean_phase, run_phase3, run_smoke, run_phase,
        # compatibility exports
        load_raw, clean_and_engineer, run_phase1, run_phase2,
        parse_cli_args, print_help, main,
        REQUIRED_COLUMNS,
        get_hour, assign_time_of_day,
        validate_schema, ensure_date_column!, enrich_features!,
        generate_plots

end # module
