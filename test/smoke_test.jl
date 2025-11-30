#!/usr/bin/env julia

# This is a smoke test script for the FlightEDA project.
# A smoke test is a preliminary test to reveal simple failures severe enough
# to reject a prospective software release. In this case, it runs the main
# data processing pipeline on a sample configuration to ensure it runs without crashing.

# Usage example from the project root directory:
#   JULIA_DEPOT_PATH=./.julia_depot ./julia-1.10.5/bin/julia --project=. test/smoke_test.jl
# You can also set the EDA_CONFIG environment variable to point to a different configuration file.

# Import the Logging package for logging messages.
using Logging

# Define the path to the `src` directory, which contains the main module.
const SRC_DIR = abspath(joinpath(@__DIR__, "..", "src"))
# Include the main `FlightEDA.jl` file. This is similar to importing a module.
Base.include(Main, joinpath(SRC_DIR, "FlightEDA.jl"))
# Bring the FlightEDA module into the current scope.
using .FlightEDA

# Define the main function that runs the smoke test.
function main()
    # Get the configuration file path from the environment variable "EDA_CONFIG".
    # If the environment variable is not set, it defaults to the sample config file.
    config_path = get(ENV, "EDA_CONFIG", joinpath(@__DIR__, "..", "config", "eda_config_sample.toml"))
    # Load the configuration from the specified path.
    cfg = FlightEDA.load_config(config_path)
    # Set up a global logger to show messages with a severity at or above the configured log level.
    global_logger(ConsoleLogger(stderr, cfg.log_level))
    # Run the smoke test function from the FlightEDA module.
    FlightEDA.run_smoke(cfg)
end

# This is a common Julia pattern. It checks if the script is being run directly.
# If it is, it calls the `main` function. This allows the script to be both
# runnable from the command line and to have its functions used in other modules.
if abspath(PROGRAM_FILE) == @__FILE__
    main()
end
