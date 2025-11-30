"""
    clean_and_engineer_data(cfg)

Phase 2: load raw data, drop unusable rows, fill delay/cancellation fields,
recompute hour features, and write the cleaned CSV.
"""
function clean_and_engineer_data(cfg::Config)
    df = load_raw_dataset(cfg)

    valid_delay(x) = !ismissing(x) && !(x isa AbstractFloat && isnan(x))

    @info "Handling missing rows and delay reasons"
    rows_before = nrow(df)
    df = filter(row ->
        (coalesce(row.cancelled, 0) == 1) ||
        (valid_delay(row.arr_delay) && valid_delay(row.dep_delay)),
    df)
    @info "Removed rows" removed = rows_before - nrow(df)

    delay_cols = [:carrier_delay, :weather_delay, :nas_delay, :security_delay, :late_aircraft_delay]
    for col in delay_cols
        if hascol(df, col)
            df[!, col] = coalesce.(df[!, col], 0.0)
        end
    end
    if hascol(df, :cancellation_code)
        df.cancellation_code = coalesce.(df.cancellation_code, "Not_Cancelled")
    end

    ensure_date_column!(df)
    if hascol(df, :crs_dep_time)
        df.hour_of_day = get_hour.(coalesce.(df.crs_dep_time, 0))
    end

    enrich_features!(df)

    out_path = cfg.data.cleaned_file
    mkpath(dirname(out_path))
    @info "Writing cleaned data" out_path
    @time CSV.write(out_path, df)
    df
end

clean_and_engineer(cfg::Config) = clean_and_engineer_data(cfg) # backward compatibility

"""
    run_clean_phase(cfg)

Execute Phase 2 cleaning/feature engineering and report missing counts.
"""
function run_clean_phase(cfg::Config)
    df = clean_and_engineer_data(cfg)
    println("\n=== AFTER CLEANING (missing counts) ===")
    println(first(describe(df, :nmissing), min(20, ncol(df))))
    @info "Phase 2 complete"
    df
end

run_phase2(cfg::Config) = run_clean_phase(cfg) # backward compatibility
