get_hour(hhmm) = if ismissing(hhmm)
    0
elseif hhmm isa AbstractString
    parsed = tryparse(Int, hhmm)
    parsed === nothing ? 0 : floor(Int, parsed / 100) % 24
else
    floor(Int, hhmm / 100) % 24
end

hascol(df::DataFrame, col::Symbol) = col in propertynames(df)

assign_time_of_day(hour) = if 6 <= hour < 11
    "Morning"
elseif 11 <= hour < 16
    "Afternoon"
elseif 16 <= hour < 21
    "Evening"
else
    "Night/Red-eye"
end

function ensure_date_column!(df::DataFrame)
    if hascol(df, :fl_date) && eltype(df.fl_date) <: AbstractString
        df.fl_date = Date.(df.fl_date, "yyyy-mm-dd")
    end
    return df
end

function ensure_hour_features!(df::DataFrame)
    hour_missing = !hascol(df, :hour_of_day)
    hour_constant = false
    if !hour_missing
        uniq_hours = unique(skipmissing(df.hour_of_day))
        hour_constant = length(uniq_hours) <= 1
    end

    needs_recompute = hour_missing || hour_constant
    if needs_recompute && hascol(df, :crs_dep_time)
        uniq_crs = unique(skipmissing(df.crs_dep_time))
        needs_recompute = needs_recompute && length(uniq_crs) > 1
    end

    if needs_recompute
        if hascol(df, :crs_dep_time)
            df.hour_of_day = get_hour.(coalesce.(df.crs_dep_time, 0))
        else
            df.hour_of_day = fill(0, nrow(df))
        end
    end

    if hascol(df, :hour_of_day) && !hascol(df, :time_of_day)
        df.time_of_day = assign_time_of_day.(df.hour_of_day)
    end
end

function validate_schema(df::DataFrame; required::Vector{Symbol}=REQUIRED_COLUMNS)
    present = Set(Symbol.(names(df)))
    missing = setdiff(required, present)
    isempty(missing) || error("Missing required columns: $(collect(missing))")
end

function enrich_features!(df::DataFrame)
    ensure_hour_features!(df)
    if hascol(df, :arr_delay) && !hascol(df, :is_delayed)
        df.is_delayed = coalesce.(df.arr_delay .>= 15, false)
    end
    if hascol(df, :origin) && hascol(df, :dest) && !hascol(df, :route)
        df.route = string.(df.origin, " → ", df.dest)
    end
    return df
end

function configure_pyplot(config_dir::String)
    mkpath(config_dir)
    ENV["MPLBACKEND"] = get(ENV, "MPLBACKEND", "Agg")
    ENV["MPLCONFIGDIR"] = get(ENV, "MPLCONFIGDIR", config_dir)
end

function describe_df(df::DataFrame)
    println("\n=== DATA SHAPE ===")
    println(size(df))
    println("\n=== FIRST 6 ROWS ===")
    println(first(df, 6))
    println("\n=== LAST 6 ROWS ===")
    println(last(df, 6))
    println("\n=== DESCRIBE() SUMMARY ===")
    println(describe(df))
end
