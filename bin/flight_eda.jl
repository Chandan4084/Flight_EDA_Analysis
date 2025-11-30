#!/usr/bin/env julia

using ArgParse
using Logging

const SRC_DIR = abspath(joinpath(@__DIR__, "..", "src"))
Base.include(Main, joinpath(SRC_DIR, "FlightEDA.jl"))
using .FlightEDA

function ensure_instantiated()
    manifest_path = abspath(joinpath(@__DIR__, "..", "Manifest.toml"))
    project_path = abspath(joinpath(@__DIR__, "..", "Project.toml"))
    if !isfile(manifest_path)
        println("🔧 Project not instantiated. Run:")
        println("  JULIA_DEPOT_PATH=./.julia_depot ./julia-1.10.5/bin/julia --project=. -e 'using Pkg; Pkg.instantiate()'")
        exit(1)
    end
    if !isfile(project_path)
        println("❌ Project.toml not found at $(project_path).")
        exit(1)
    end
end

function build_parser()
    s = ArgParseSettings()
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
    end
    s
end

function main()
    ensure_instantiated()
    parser = build_parser()
    parsed = parse_args(parser)
    phase = FlightEDA.parse_phase(get(parsed, "phase", "all"))
    config_path = get(ENV, "EDA_CONFIG", get(parsed, "config", FlightEDA.DEFAULT_CONFIG_PATH))

    cfg = FlightEDA.load_config(config_path)
    level_override = FlightEDA.log_level_from_string(get(parsed, "log_level", "info"))
    cfg = FlightEDA.Config(cfg.data, cfg.plots, level_override)

    FlightEDA.global_logger(ConsoleLogger(stderr, cfg.log_level))
    FlightEDA.run_phase(phase, cfg)
end

if abspath(PROGRAM_FILE) == @__FILE__
    main()
end
