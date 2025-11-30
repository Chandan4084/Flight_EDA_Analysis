# This function parses the phase argument from the command line.
# It allows the user to specify which part of the analysis to run.
function parse_phase(val::AbstractString)
    s = lowercase(val)
    s in ["1", "phase1", "load"] && return :phase1
    s in ["2", "phase2", "clean"] && return :phase2
    s in ["3", "phase3", "plots"] && return :phase3
    s in ["all"] && return :all
    s in ["smoke"] && return :smoke
    error("Unsupported phase value: $val")
end

# This function parses the command-line arguments provided by the user.
# It determines which phase to run and where to find the configuration file.
function parse_cli_args(args::Vector{String})
    phase = :all
    config_path = DEFAULT_CONFIG_PATH
    i = 1
    while i <= length(args)
        arg = args[i]
        if arg in ["-h", "--help"]
            return (:help, config_path)
        elseif arg == "--phase"
            i += 1
            i <= length(args) || error("Missing value for --phase")
            phase = parse_phase(args[i])
        elseif arg == "--config"
            i += 1
            i <= length(args) || error("Missing value for --config")
            config_path = args[i]
        else
            error("Unknown argument: $arg")
        end
        i += 1
    end
    return (phase, config_path)
end

# This function prints a help message to the console.
# It explains how to use the command-line interface.
function print_help()
    println("Usage: julia --project=. bin/flight_eda.jl [--phase <1|2|3|all|smoke>] [--config <path>]")
    println()
    println("Phases:")
    println("  1 / phase1 / load   - Load and profile raw data")
    println("  2 / phase2 / clean  - Clean and engineer features, save cleaned CSV")
    println("  3 / phase3 / plots  - Generate all plots")
    println("  all                 - Run phases 1 -> 3")
    println("  smoke               - Run smoke test on sample/cleaned data")
    println()
    println("Env override: set EDA_CONFIG=<path> to point at a config file")
end

# This is the main function of the application.
# It parses the command-line arguments, loads the configuration,
# and runs the specified phase of the analysis.
function main(args=ARGS)
    phase, config_path = parse_cli_args(args)
    phase === :help && return print_help()

    config_path = get(ENV, "EDA_CONFIG", config_path)
    cfg = load_config(config_path)

    global_logger(ConsoleLogger(stderr, cfg.log_level))
    run_phase(phase, cfg)
end

# This line ensures that the main function is called when the script is executed.
if abspath(PROGRAM_FILE) == @__FILE__
    main()
end
