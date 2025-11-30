"""
    clean_and_engineer_data(cfg)

Phase 2: load raw data, drop unusable rows, fill delay/cancellation fields,
recompute hour features, and write the cleaned CSV.
"""
function clean_and_engineer_data(cfg::Config)
    clean_and_engineer_data(cfg; df_raw=nothing)
end

function clean_and_engineer_data(cfg::Config; df_raw::Union{Nothing,DataFrame}=nothing)
    df = df_raw === nothing ? load_raw_dataset(cfg) : df_raw

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

    # Persist cancelled/diverted flights separately so plots can use them.
    out_path = cfg.data.cleaned_file
    cancellation_out_path = replace(out_path, r"\.csv$" => "_cancellations.csv")
    df_cancel = filter(row -> begin
        cancelled_val = hasproperty(row, :cancelled) ? coalesce(row.cancelled, 0) : 0
        diverted_val = hasproperty(row, :diverted) ? coalesce(row.diverted, 0) : 0
        cancelled_val == 1 || diverted_val == 1
    end, df)
    if !isempty(df_cancel)
        mkpath(dirname(cancellation_out_path))
        @info "Writing cancellations/diversions dataset" cancellation_out_path
        @time CSV.write(cancellation_out_path, df_cancel)
    end

    # Drop cancelled/diverted flights and rows missing core timing fields for clean analysis
    rows_before = nrow(df)
    df = filter(row -> begin
        cancelled_val = hasproperty(row, :cancelled) ? coalesce(row.cancelled, 0) : 0
        diverted_val = hasproperty(row, :diverted) ? coalesce(row.diverted, 0) : 0
        cancelled_val == 0 && diverted_val == 0
    end, df)
    @info "Dropped cancelled/diverted flights" removed = rows_before - nrow(df)

    rows_before = nrow(df)
    required = [:dep_time, :arr_time, :dep_delay, :arr_delay, :distance]
    present_required = intersect(required, Symbol.(names(df)))
    if !isempty(present_required)
        df = dropmissing(df, present_required)
        @info "Dropped rows missing core timing fields" removed = rows_before - nrow(df)
    end

    enrich_features!(df)

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
function run_clean_phase(cfg::Config; df_raw::Union{Nothing,DataFrame}=nothing)
    df = clean_and_engineer_data(cfg; df_raw=df_raw)
    println("\n=== AFTER CLEANING (missing counts) ===")
    println(first(describe(df, :nmissing), min(20, ncol(df))))
    @info "Phase 2 complete"
    df
end

run_phase2(cfg::Config) = run_clean_phase(cfg) # backward compatibility
