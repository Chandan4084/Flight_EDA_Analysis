# This function performs a "smoke test". A smoke test is a quick, basic test
# to ensure that the most crucial functions of a program work correctly.
function run_smoke(cfg::Config)
    # Get the file paths for the sample data and the cleaned data from the configuration.
    sample_path = cfg.data.sample_file
    clean_path = cfg.data.cleaned_file

    # Decide which file to load for the test.
    # It first checks if the sample file exists.
    # If not, it checks if the cleaned file exists.
    # If neither exists, it throws an error because there's no data to test.
    file_to_load = if isfile(sample_path)
        sample_path
    elseif isfile(clean_path)
        clean_path
    else
        error("No data file found. Expected one of: $sample_path or $clean_path")
    end

    # Log which file is being used for the smoke test.
    @info "Running smoke test" file_to_load
    # Read the chosen CSV file into a DataFrame. A DataFrame is a table-like data structure.
    df = CSV.read(file_to_load, DataFrame)

    # These functions add or modify columns in the DataFrame.
    # `ensure_date_column!` makes sure there's a proper date column.
    ensure_date_column!(df)
    # `enrich_features!` adds new, calculated columns (features) to the DataFrame.
    enrich_features!(df)

    # Define a list of columns that are absolutely required for the program to work.
    required_cols = [:arr_delay, :dep_delay, :distance, :hour_of_day, :is_delayed, :route]
    # Check which of the required columns are missing from the DataFrame.
    missing_cols = setdiff(required_cols, Symbol.(names(df)))
    # If the list of missing columns is not empty, throw an error.
    isempty(missing_cols) || error("Missing expected columns: $(missing_cols)")

    # Assert that the 'fl_date' column has been correctly converted to the `Date` type.
    # `@assert` is a check that will throw an error if its condition is false.
    @assert eltype(df.fl_date) <: Date "fl_date not converted to Date"

    # Print out the dimensions of the DataFrame (number of rows and columns).
    println("Shape: $(nrow(df)) rows × $(ncol(df)) cols")
    # Print a header for the missing values report.
    println("Missing counts (first 10):")
    # Print a summary of missing values for the first 10 columns.
    println(first(describe(df, :nmissing), min(10, ncol(df))))
    # If the script reaches this point without any errors, the smoke test is considered passed.
    @info "Smoke test passed"
end
