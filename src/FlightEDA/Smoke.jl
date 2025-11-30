function run_smoke(cfg::Config)
    sample_path = cfg.data.sample_file
    clean_path = cfg.data.cleaned_file
    file_to_load = if isfile(sample_path)
        sample_path
    elseif isfile(clean_path)
        clean_path
    else
        error("No data file found. Expected one of: $sample_path or $clean_path")
    end
    @info "Running smoke test" file_to_load
    df = CSV.read(file_to_load, DataFrame)
    ensure_date_column!(df)
    enrich_features!(df)

    required_cols = [:arr_delay, :dep_delay, :distance, :hour_of_day, :is_delayed, :route]
    missing_cols = setdiff(required_cols, Symbol.(names(df)))
    isempty(missing_cols) || error("Missing expected columns: $(missing_cols)")
    @assert eltype(df.fl_date) <: Date "fl_date not converted to Date"

    println("Shape: $(nrow(df)) rows × $(ncol(df)) cols")
    println("Missing counts (first 10):")
    println(first(describe(df, :nmissing), min(10, ncol(df))))
    @info "Smoke test passed"
end
