"""
    load_raw_dataset(cfg)

Read the configured raw CSV, enforce schema/date parsing, and return a DataFrame.
"""
function load_raw_dataset(cfg::Config)
    path = cfg.data.raw_file
    isfile(path) || error("Raw data not found at $path")
    @info "Loading raw dataset" path
    @time df = CSV.read(path, DataFrame)
    validate_schema(df)
    ensure_date_column!(df)
    df
end

load_raw(cfg::Config) = load_raw_dataset(cfg) # backward compatibility

"""
    run_load_phase(cfg)

Load and profile the raw data (Phase 1).
"""
function run_load_phase(cfg::Config)
    df = load_raw_dataset(cfg)
    FlightEDA.describe_df(df)
    @info "Phase 1 complete"
    df
end

run_phase1(cfg::Config) = run_load_phase(cfg) # backward compatibility
