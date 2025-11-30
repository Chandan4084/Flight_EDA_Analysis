# Helper function to create a full file path for a plot.
# It joins a directory path and a plot name, and adds the ".png" extension.
plot_filename(name, dir) = joinpath(dir, "$(name).png")

# --- INDIVIDUAL PLOTTING FUNCTIONS ---

# Creates and saves a histogram of arrival delays.
function plot_arrival_delay_histogram(df, lower, upper, plot_dir)
    # Filter the data to include only delays within the specified lower and upper bounds.
    df1 = filter(:arr_delay => d -> !ismissing(d) && lower < d < upper, df)
    # Create a histogram of the arrival delays.
    histogram(df1.arr_delay; bins=120, xlabel="Delay (min)", ylabel="Flights",
        title="Arrival Delay Distribution", size=(600, 400))
    # Save the plot to a file.
    savefig(plot_filename("1_hist_arrival_delay", plot_dir))
end

# Creates and saves a bar chart showing the number of flights for each airline.
function plot_flight_counts_by_airline(df, plot_dir)
    # Group the data by airline and count the number of flights for each.
    c = combine(groupby(df, :op_unique_carrier), nrow => :flight_count)
    # Sort the airlines by flight count in descending order.
    sort!(c, :flight_count, rev=true)
    # Create a bar chart.
    bar(c.op_unique_carrier, c.flight_count; xlabel="", ylabel="Flights",
        title="Flights by Airline", xticks=:all, legend=false, size=(700, 400), xrotation=60)
    savefig(plot_filename("2_flights_by_airline", plot_dir))
end

# Creates and saves a bar chart of the top 15 busiest airports.
function plot_top_busiest_airports(df, plot_dir)
    # Group by origin airport and count the number of departing flights.
    c2 = combine(groupby(df, :origin), nrow => :flight_count)
    # Sort the airports by flight count in descending order.
    sort!(c2, :flight_count, rev=true)
    # Select the top 15 airports.
    top15 = first(c2, min(15, nrow(c2)))
    # Create a bar chart of the top 15.
    bar(top15.origin, top15.flight_count; xlabel="", ylabel="Flights",
        title="Top 15 Busiest Airports", xticks=:all, legend=false, size=(700, 400), xrotation=45)
    savefig(plot_filename("3_busiest_airports", plot_dir))
end

# Creates and saves a bar chart of flight cancellation reasons.
function plot_cancellation_reason_counts(df, cfg::Config, plot_dir)
    # Start with cancellations present in the provided DataFrame.
    dfc = filter(:cancellation_code => c -> !ismissing(c) && c != "Not_Cancelled", df)

    # Prefer the dedicated cancellations file if present (written during cleaning).
    cancellation_path = replace(cfg.data.cleaned_file, r"\.csv$" => "_cancellations.csv")
    if isfile(cancellation_path)
        @info "Loading cancellations dataset for cancellation plot" cancellation_path
        dfc = CSV.read(cancellation_path, DataFrame)
    end

    # If still empty, fall back to raw.
    if isempty(dfc)
        raw_path = cfg.data.raw_file
        if isfile(raw_path)
            @info "Reloading raw dataset for cancellation plot" raw_path
            df_raw = CSV.read(raw_path, DataFrame)
            dfc = filter(:cancellation_code => c -> !ismissing(c) && c != "Not_Cancelled", df_raw)
        end
    end

    if isempty(dfc)
        @warn "No cancellations found; skipping cancellation plot"
        return
    end

    # Group by cancellation reason and count the occurrences.
    c3 = combine(groupby(dfc, :cancellation_code), nrow => :count)
    # Create a bar chart of the reasons.
    bar(c3.cancellation_code, c3.count; xlabel="", ylabel="Flights",
        title="Cancellation Reasons", legend=false, size=(500, 400))
    savefig(plot_filename("4_cancellation_reasons", plot_dir))
end

# Creates and saves a line plot of the average arrival delay for each hour of the day.
function plot_average_delay_by_hour(df, plot_dir)
    # Group by hour and calculate the mean arrival delay, skipping any missing values.
    c4 = combine(groupby(df, :hour_of_day), :arr_delay => (mean ∘ skipmissing) => :mean_delay)
    # Sort by hour to make the line plot sequential.
    sort!(c4, :hour_of_day)
    # Create a line plot.
    plot(c4.hour_of_day, c4.mean_delay; marker=:circle, xlabel="Hour", ylabel="Delay (min)",
        title="Avg Delay by Hour", grid=true, size=(600, 400))
    savefig(plot_filename("5_delay_by_hour", plot_dir))
end

# Creates and saves a bar chart of the average delay for each airline.
function plot_average_delay_by_airline(df, plot_dir)
    # Group by airline and calculate the mean arrival delay.
    c5 = combine(groupby(df, :op_unique_carrier), :arr_delay => (mean ∘ skipmissing) => :mean_delay)
    # Sort by the mean delay to easily see the best and worst airlines.
    sort!(c5, :mean_delay)
    # Create a bar chart.
    bar(c5.op_unique_carrier, c5.mean_delay; xlabel="", ylabel="Avg delay (min)",
        title="Avg Delay by Airline", legend=false, size=(700, 400), xrotation=60)
    savefig(plot_filename("6_delay_by_airline", plot_dir))
end

# Creates and saves a box plot showing the distribution of arrival delays for each airline.
function plot_arrival_delay_boxplot_by_airline(df, lower, upper, plot_dir)
    # Filter out extreme delay values to make the plot readable.
    df_box = filter(:arr_delay => d -> !ismissing(d) && !isnan(d) && lower < d < upper, df)
    # Create a box plot with airlines on the X-axis and arrival delay on the Y-axis.
    @df df_box boxplot(:op_unique_carrier, :arr_delay; legend=false,
        ylabel="Arrival delay (min)", title="Delay Distribution by Airline",
        size=(800, 400), xrotation=60)
    savefig(plot_filename("7_boxplot_by_airline", plot_dir))
end

# Creates a scatter plot of departure delay vs. arrival delay for a random sample of flights.
function plot_departure_vs_arrival_scatter(df, lower, upper, sample_size, plot_dir)
    # Set a random seed for reproducibility of the sample.
    Random.seed!(123)
    # Determine the sample size, ensuring it's not larger than the dataset.
    sample_size = min(nrow(df), sample_size)
    # Randomly shuffle the row indices and take a sample.
    sample_idx = shuffle(1:nrow(df))[1:sample_size]
    dfs = df[sample_idx, :]
    # Filter the sample to remove missing and extreme values.
    dfs = filter(row ->
        !ismissing(row.arr_delay) && !ismissing(row.dep_delay) &&
        lower < row.arr_delay < upper && lower < row.dep_delay < upper,
    dfs)
    # Create the scatter plot.
    scatter(dfs.dep_delay, dfs.arr_delay; alpha=0.3, markersize=2.5,
        xlabel="Departure Delay", ylabel="Arrival Delay",
        title="Departure vs Arrival Delay (Sample)", grid=true, size=(600, 600))
    savefig(plot_filename("8_scatter_dep_arr", plot_dir))
end

# Creates a bar chart of the worst routes with the highest average delays.
function plot_worst_average_delay_routes(df, cfg, plot_dir)
    # Chain data operations to find the worst routes.
    top_routes = df |>
        # Filter out rows with invalid arrival delays (NaNs).
        df -> filter(:arr_delay => d -> !(d isa AbstractFloat && isnan(d)), df) |>
        # Group by route and calculate flight count and mean delay.
        df -> groupby(df, [:origin, :dest]) |>
        df -> combine(df,
            nrow => :flight_count,
            :arr_delay => (mean ∘ skipmissing) => :mean_delay
        ) |>
        # Filter out routes with too few flights to be statistically significant.
        df -> filter(:flight_count => c -> c >= cfg.plots.route_min_flights, df) |>
        # Sort by mean delay to find the worst routes.
        df -> sort(df, :mean_delay, rev=true) |>
        # Take the top N worst routes.
        df -> first(df, min(cfg.plots.route_top_n, nrow(df)))

    if isempty(top_routes)
        @warn "No routes met the criteria for 'worst routes' plot; skipping."
        return
    end

    # Create a 'route' string for labeling.
    top_routes.route = string.(top_routes.origin, " → ", top_routes.dest)
    topn = nrow(top_routes)
    # Create a vertical bar chart with route labels on X and delays on Y.
    bar(top_routes.route, top_routes.mean_delay;
        xlabel="Route", ylabel="Avg arrival delay (min)",
        title="Top $(topn) Worst Routes (min $(cfg.plots.route_min_flights) flights)",
        legend=false, size=(1500, 600), xrotation=0,
        xtickfont=font(8), ytickfont=font(9),
        yticks=collect(0:50:ceil(Int, maximum(top_routes.mean_delay) + 50)),
        grid=true)
    savefig(plot_filename("10_worst_routes", plot_dir))
end

# Creates a heatmap showing the rate of delays by day of the week and hour of the day.
function plot_delay_rate_heatmap(df, plot_dir)
    # Ensure hour and 'is_delayed' features are present.
    ensure_hour_features!(df)
    if !hascol(df, :is_delayed)
        df.is_delayed = hascol(df, :arr_delay) ? coalesce.(df.arr_delay .>= 15, false) : fill(false, nrow(df))
    end
    # Create a 'day_of_week' column from the flight date.
    df.day_of_week = dayofweek.(df.fl_date)
    # Group by day and hour, and calculate the mean delay rate.
    c11 = combine(groupby(df, [:day_of_week, :hour_of_day]), :is_delayed => (mean ∘ skipmissing) => :delay_rate)
    days = 1:7; hours = 0:23
    # Create a complete grid of all days and hours to ensure the heatmap is always rectangular.
    template = DataFrame(day_of_week=repeat(collect(days), inner=length(hours)),
                         hour_of_day=repeat(collect(hours), outer=length(days)))
    c11_complete = leftjoin(template, c11, on=[:day_of_week, :hour_of_day])
    # Reshape the data from a "long" to a "wide" format suitable for a heatmap.
    wide11 = unstack(c11_complete, :day_of_week, :hour_of_day, :delay_rate)
    # Convert the data to a matrix and create the heatmap.
    plotmat = Matrix(wide11[!, 2:end])
    heatmap(0:23, ["Mon","Tue","Wed","Thu","Fri","Sat","Sun"], plotmat';
        xlabel="Hour", ylabel="Day", title="Delay Rate by Day & Hour",
        colorbar_title="Delay rate", size=(800, 400))
    savefig(plot_filename("11_heatmap", plot_dir))
end

# Creates a grid of small plots (facets), each showing avg delay by hour for a top airline.
function plot_delay_by_hour_facets(df, ccount, plot_dir)
    # Get the top 8 airlines by flight count.
    top8 = first(ccount.op_unique_carrier, min(8, length(ccount.op_unique_carrier)))
    # Filter the DataFrame for these airlines.
    df8 = filter(:op_unique_carrier => c -> !ismissing(c) && c in top8, df)
    # Group by airline and hour, and calculate mean delay.
    c12 = combine(groupby(df8, [:op_unique_carrier, :hour_of_day]), :arr_delay => (mean ∘ skipmissing) => :mean_delay)
    sort!(c12, [:op_unique_carrier, :hour_of_day])
    plots = []
    # Loop through each of the top 8 airlines to create a plot for each one.
    for carrier in top8
        subset = filter(:op_unique_carrier => c -> c == carrier, c12)
        p = plot(subset.hour_of_day, subset.mean_delay; marker=:circle, title=String(carrier),
            xlabel="Hour", ylabel="Avg delay", grid=true)
        push!(plots, p)
    end
    # Define the layout for the grid of plots (4 rows, 2 columns).
    l = @layout [a b; c d; e f; g h]
    # Combine all the individual plots into a single figure.
    plt = plot(plots...; layout=l, size=(1000, 1000), title="Delay by Hour (Top 8 Airlines)")
    savefig(plot_filename("12_facet_airline_hour", plot_dir))
end


# --- MAIN PLOT GENERATION FUNCTION ---

# This function orchestrates the entire plot generation process.
function generate_plots(cfg::Config, df_in::Union{Nothing,DataFrame}=nothing)
    # Set the backend for the Plots.jl library.
    gr()

    # Load the cleaned data if a DataFrame is not already provided.
    df = if df_in === nothing
        clean_file = cfg.data.cleaned_file
        isfile(clean_file) || error("Cleaned file not found. Run Phase 2 first. Expected at $clean_file")
        @info "Loading cleaned dataset" clean_file
        @time CSV.read(clean_file, DataFrame)
    else
        df_in # Use the provided DataFrame.
    end
    # Ensure necessary features and date formats are present.
    ensure_date_column!(df)
    enrich_features!(df)

    # Get the output directory for plots from the configuration and create it if it doesn't exist.
    plot_dir = cfg.plots.dir
    mkpath(plot_dir)

    # Get the delay boundaries from the configuration for filtering.
    lower = cfg.plots.delay_lower
    upper = cfg.plots.delay_upper

    @info "Generating plots" output_dir = plot_dir

    # Call all the individual plotting functions.
    plot_arrival_delay_histogram(df, lower, upper, plot_dir)
    plot_flight_counts_by_airline(df, plot_dir)
    plot_top_busiest_airports(df, plot_dir)
    plot_cancellation_reason_counts(df, cfg, plot_dir)
    plot_average_delay_by_hour(df, plot_dir)
    plot_average_delay_by_airline(df, plot_dir)
    plot_arrival_delay_boxplot_by_airline(df, lower, upper, plot_dir)
    plot_departure_vs_arrival_scatter(df, lower, upper, cfg.plots.scatter_sample_size, plot_dir)

    # Pre-calculate airline counts, as it's needed by multiple plot functions.
    ccount = combine(groupby(df, :op_unique_carrier), nrow => :flight_count)
    sort!(ccount, :flight_count, rev=true)

    plot_worst_average_delay_routes(df, cfg, plot_dir)
    plot_delay_rate_heatmap(df, plot_dir)
    plot_delay_by_hour_facets(df, ccount, plot_dir)

    @info "All plots saved" plot_dir
    # Return the DataFrame that was used for plotting.
    df
end
