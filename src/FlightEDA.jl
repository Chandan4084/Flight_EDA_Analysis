# This is the main module for the FlightEDA project.
# It brings together all the different parts of the project
# and makes them available for use.
__precompile__(false)
module FlightEDA

# These are the external packages that we need to use.
# They provide functions for working with CSV files, data frames,
# dates, logging, random numbers, statistics, configuration files,
# and plots.
using CSV
using DataFrames
using Dates
using Logging
using Random
using Statistics
using TOML
using Plots
using StatsPlots

# These lines include the other files in the project.
# Each file contains a specific part of the functionality.
include("FlightEDA/Config.jl") # Handles configuration settings
include("FlightEDA/Utils.jl") # Provides utility functions
include("FlightEDA/Plotting.jl") # Contains functions for creating plots
include("FlightEDA/Smoke.jl") # Includes a simple smoke test
include("FlightEDA/Phases.jl") # Defines the different data processing phases
include("FlightEDA/CLI.jl") # Handles the command-line interface

# This section lists the functions and types that are made available
# to other modules that use this one.
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
