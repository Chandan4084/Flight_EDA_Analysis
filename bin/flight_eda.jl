#!/usr/bin/env julia

# This script is the main entry point for the Flight EDA (Exploratory Data Analysis) application.
# It uses the ArgParse package to handle command-line arguments and Logging for displaying messages.

# Import the necessary packages.
using ArgParse
using Logging

# Define the absolute path to the 'src' directory, which contains the main source code.
# __DIR__ is a special variable that represents the directory of the current file.
# abspath ensures the path is absolute (e.g., C:\Users\...).
const SRC_DIR = abspath(joinpath(@__DIR__, "..", "src"))

# Include the main module file for the project. This is similar to 'import' in other languages.
Base.include(Main, joinpath(SRC_DIR, "FlightEDA.jl"))

# After including the file, we can now 'use' the module to bring its functions into scope.
using .FlightEDA

# This function checks if the project's dependencies are installed.
# It looks for Manifest.toml, which is created when you run 'Pkg.instantiate()'.
function ensure_instantiated()
    # Get the absolute paths for the Manifest.toml and Project.toml files.
    manifest_path = abspath(joinpath(@__DIR__, "..", "Manifest.toml"))
    project_path = abspath(joinpath(@__DIR__, "..", "Project.toml"))

    # If Manifest.toml doesn't exist, it means dependencies are not installed.
    if !isfile(manifest_path)
        println("🔧 Project not instantiated. Run:")
        println("  julia --project=. -e 'using Pkg; Pkg.instantiate()'")
        # Exit the script with an error code.
        exit(1)
    end

    # Project.toml should always exist in a Julia project.
    if !isfile(project_path)
        println("❌ Project.toml not found at $(project_path).")
        exit(1)
    end
end

# This function sets up the command-line arguments that the script can accept.
function build_parser()
    # Create a new settings object for ArgParse.
    s = ArgParseSettings()

    # Add the available arguments to the settings.
    @add_arg_table s begin
        "--phase"
        help = "Which phase to run (1|2|3|all|smoke)"
        arg_type = String
        default = "all"

        "--config"
        help = "Path to config TOML (default: config/eda_config.toml)"
        arg_type = String
        default = FlightEDA.DEFAULT_CONFIG_PATH

        "--log-level"
        help = "Log level (debug|info|warn|error)"
        arg_type = String
        default = "info"

        "--profile"
        help = "Run profiling for the specified phase"
        action = :store_true
    end
    # Return the settings object.
    s
end

# This is the main function where the script's logic resides.
function main()
    # First, make sure the project is ready to go.
    ensure_instantiated()

    # Set up the argument parser.
    parser = build_parser()

    # Parse the arguments provided by the user when they run the script.
    parsed = parse_args(parser)

    # Check if we are running in profile mode.
    if parsed["profile"]
        # Include the profiling module.
        Base.include(Main, joinpath(SRC_DIR, "FlightEDA", "Profile.jl"))
        # Run the profiler with the given phase.
        Main.Profile.run_profile(get(parsed, "phase", "all"))
    else
        # Get the desired phase from the parsed arguments, defaulting to "all".
        phase = FlightEDA.parse_phase(get(parsed, "phase", "all"))

        # Get the path to the configuration file. It can be set via an environment variable (EDA_CONFIG)
        # or a command-line argument, with a final fallback to the default path.
        config_path = get(ENV, "EDA_CONFIG", get(parsed, "config", FlightEDA.DEFAULT_CONFIG_PATH))

        # Load the configuration from the TOML file.
        cfg = FlightEDA.load_config(config_path)

        # Get the log level from the command-line arguments and override the one from the config file.
        level_override = FlightEDA.log_level_from_string(get(parsed, "log_level", "info"))

        # Create a new Config object with the potentially updated log level.
        cfg = FlightEDA.Config(cfg.data, cfg.plots, level_override)

        # Set up the global logger to show messages in the console.
        # The log level from the config determines which messages are shown (e.g., 'info' and above).
        FlightEDA.global_logger(ConsoleLogger(stderr, cfg.log_level))

        # Run the specified analysis phase with the loaded configuration.
        FlightEDA.run_phase(phase, cfg)
    end
end

# This common Julia pattern checks if the script is being run directly.
# If it is, it calls the main() function. This allows the file to be included
# in other scripts without automatically running the analysis.
if abspath(PROGRAM_FILE) == @__FILE__
    main()
end
