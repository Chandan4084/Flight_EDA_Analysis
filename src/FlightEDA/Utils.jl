# This function extracts the hour from a time given in HHMM format.
# It can handle missing values, strings, or numbers.
get_hour(hhmm) = if ismissing(hhmm)
    0 # Return 0 if the time is missing.
elseif hhmm isa AbstractString
    # If the time is a string, try to parse it as an integer.
    parsed = tryparse(Int, hhmm)
    # If parsing fails, return 0. Otherwise, calculate the hour.
    # Division by 100 gets the HH part, and modulo 24 ensures it's a valid hour (0-23).
    parsed === nothing ? 0 : floor(Int, parsed / 100) % 24
else
    # If the time is a number, calculate the hour directly.
    floor(Int, hhmm / 100) % 24
end

# A convenience function to check if a DataFrame `df` has a column named `col`.
# It returns `true` if the column exists, `false` otherwise.
hascol(df::DataFrame, col::Symbol) = col in propertynames(df)

# This function takes an hour (0-23) and returns a string describing the time of day.
assign_time_of_day(hour) = if 6 <= hour < 11
    "Morning"
elseif 11 <= hour < 16
    "Afternoon"
elseif 16 <= hour < 21
    "Evening"
else
    "Night/Red-eye"
end

# This function ensures the flight date column is in the correct `Date` format.
# The `!` at the end of the function name is a Julia convention indicating
# that the function modifies its input (`df`).
function ensure_date_column!(df::DataFrame)
    # If the `fl_date` column exists and contains strings...
    if hascol(df, :fl_date) && eltype(df.fl_date) <: AbstractString
        # ...convert the strings to `Date` objects, assuming "yyyy-mm-dd" format.
        df.fl_date = Date.(df.fl_date, "yyyy-mm-dd")
    end
    # Return the modified DataFrame.
    return df
end

# This function ensures that `hour_of_day` and `time_of_day` features exist and are meaningful.
function ensure_hour_features!(df::DataFrame)
    # Check if the `hour_of_day` column is missing.
    hour_missing = !hascol(df, :hour_of_day)
    hour_constant = false
    if !hour_missing
        # If the column exists, check if it contains only one unique value (making it constant).
        uniq_hours = unique(skipmissing(df.hour_of_day))
        hour_constant = length(uniq_hours) <= 1
    end

    # We need to recompute the hour if it's missing or constant.
    needs_recompute = hour_missing || hour_constant
    # Also, recomputing only makes sense if the source `crs_dep_time` has more than one unique value.
    if needs_recompute && hascol(df, :crs_dep_time)
        uniq_crs = unique(skipmissing(df.crs_dep_time))
        needs_recompute = needs_recompute && length(uniq_crs) > 1
    end

    # If we decided a recompute is needed...
    if needs_recompute
        if hascol(df, :crs_dep_time)
            # ...calculate `hour_of_day` from the scheduled departure time (`crs_dep_time`).
            df.hour_of_day = get_hour.(coalesce.(df.crs_dep_time, 0))
        else
            # If there's no source time, fill the column with zeros.
            df.hour_of_day = fill(0, nrow(df))
        end
    end

    # If `hour_of_day` exists but `time_of_day` doesn't...
    if hascol(df, :hour_of_day) && !hascol(df, :time_of_day)
        # ...create the `time_of_day` column by applying the `assign_time_of_day` function.
        df.time_of_day = assign_time_of_day.(df.hour_of_day)
    end
end

# This function validates that a DataFrame `df` has a set of required columns.
function validate_schema(df::DataFrame; required::Vector{Symbol}=REQUIRED_COLUMNS)
    # Get the set of columns currently in the DataFrame.
    present = Set(Symbol.(names(df)))
    # Find which required columns are missing.
    missing_cols = setdiff(required, present)
    # If any columns are missing, throw an error.
    isempty(missing_cols) || error("Missing required columns: $(collect(missing_cols))")
end

# This function adds several new, useful columns (features) to the DataFrame.
function enrich_features!(df::DataFrame)
    # First, make sure the hour-based features are present.
    ensure_hour_features!(df)
    # If there's an `arr_delay` column but no `is_delayed` column...
    if hascol(df, :arr_delay) && !hascol(df, :is_delayed)
        # ...create `is_delayed`, which is `true` if the arrival delay is 15 minutes or more.
        df.is_delayed = coalesce.(df.arr_delay .>= 15, false)
    end
    # If there are origin and destination columns but no `route` column...
    if hascol(df, :origin) && hascol(df, :dest) && !hascol(df, :route)
        # ...create a `route` column by combining origin and destination.
        df.route = string.(df.origin, " → ", df.dest)
    end
    # Return the modified DataFrame.
    return df
end

# This function configures the environment for the PyPlot plotting library.
function configure_pyplot(config_dir::String)
    # Create the configuration directory if it doesn't exist.
    mkpath(config_dir)
    # Set the Matplotlib backend. "Agg" is a non-interactive backend that saves plots to files.
    ENV["MPLBACKEND"] = get(ENV, "MPLBACKEND", "Agg")
    # Set the directory where Matplotlib should store its configuration files.
    ENV["MPLCONFIGDIR"] = get(ENV, "MPLCONFIGDIR", config_dir)
end

# This function prints a comprehensive summary of a DataFrame.
function describe_df(df::DataFrame)
    println("\n=== DATA SHAPE ===")
    # Print the number of rows and columns.
    println(size(df))
    println("\n=== FIRST 6 ROWS ===")
    # Print the first 6 rows of the data.
    println(first(df, 6))
    println("\n=== LAST 6 ROWS ===")
    # Print the last 6 rows of the data.
    println(last(df, 6))
    println("\n=== DESCRIBE() SUMMARY ===")
    # Print a statistical summary without mean/median for brevity.
    println(describe(df, :min, :q25, :q75, :max, :nmissing, :eltype))
end
