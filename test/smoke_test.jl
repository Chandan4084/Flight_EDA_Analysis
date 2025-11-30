#!/usr/bin/env julia

# Smoke test entrypoint that exercises the pipeline on the sample config.
# Usage:
#   JULIA_DEPOT_PATH=./.julia_depot ./julia-1.10.5/bin/julia --project=. test/smoke_test.jl
# Optional: set EDA_CONFIG to point to another config.

using Logging

const SRC_DIR = abspath(joinpath(@__DIR__, "..", "src"))
Base.include(Main, joinpath(SRC_DIR, "FlightEDA.jl"))
using .FlightEDA

function main()
    config_path = get(ENV, "EDA_CONFIG", joinpath(@__DIR__, "..", "config", "eda_config_sample.toml"))
    cfg = FlightEDA.load_config(config_path)
    global_logger(ConsoleLogger(stderr, cfg.log_level))
    FlightEDA.run_smoke(cfg)
end

if abspath(PROGRAM_FILE) == @__FILE__
    main()
end
