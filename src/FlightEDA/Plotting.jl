plot_filename(name, dir) = joinpath(dir, "$(name).png")

function plot_arrival_delay_histogram(df, lower, upper, plot_dir)
    df1 = filter(:arr_delay => d -> !ismissing(d) && lower < d < upper, df)
    histogram(df1.arr_delay; bins=120, xlabel="Delay (min)", ylabel="Flights",
        title="Arrival Delay Distribution", size=(600, 400))
    savefig(plot_filename("1_hist_arrival_delay", plot_dir))
end

function plot_flight_counts_by_airline(df, plot_dir)
    c = combine(groupby(df, :op_unique_carrier), nrow => :flight_count)
    sort!(c, :flight_count, rev=true)
    bar(c.op_unique_carrier, c.flight_count; xlabel="", ylabel="Flights",
        title="Flights by Airline", xticks=:all, legend=false, size=(700, 400), xrotation=60)
    savefig(plot_filename("2_flights_by_airline", plot_dir))
end

function plot_top_busiest_airports(df, plot_dir)
    c2 = combine(groupby(df, :origin), nrow => :flight_count)
    sort!(c2, :flight_count, rev=true)
    top15 = first(c2, min(15, nrow(c2)))
    bar(top15.origin, top15.flight_count; xlabel="", ylabel="Flights",
        title="Top 15 Busiest Airports", xticks=:all, legend=false, size=(700, 400), xrotation=45)
    savefig(plot_filename("3_busiest_airports", plot_dir))
end

function plot_cancellation_reason_counts(df, plot_dir)
    dfc = filter(:cancellation_code => c -> !ismissing(c) && c != "Not_Cancelled", df)
    c3 = combine(groupby(dfc, :cancellation_code), nrow => :count)
    bar(c3.cancellation_code, c3.count; xlabel="", ylabel="Flights",
        title="Cancellation Reasons", legend=false, size=(500, 400))
    savefig(plot_filename("4_cancellation_reasons", plot_dir))
end

function plot_average_delay_by_hour(df, plot_dir)
    c4 = combine(groupby(df, :hour_of_day), :arr_delay => (mean ∘ skipmissing) => :mean_delay)
    sort!(c4, :hour_of_day)
    plot(c4.hour_of_day, c4.mean_delay; marker=:circle, xlabel="Hour", ylabel="Delay (min)",
        title="Avg Delay by Hour", grid=true, size=(600, 400))
    savefig(plot_filename("5_delay_by_hour", plot_dir))
end

function plot_average_delay_by_airline(df, plot_dir)
    c5 = combine(groupby(df, :op_unique_carrier), :arr_delay => (mean ∘ skipmissing) => :mean_delay)
    sort!(c5, :mean_delay)
    bar(c5.op_unique_carrier, c5.mean_delay; xlabel="", ylabel="Avg delay (min)",
        title="Avg Delay by Airline", legend=false, size=(700, 400), xrotation=60)
    savefig(plot_filename("6_delay_by_airline", plot_dir))
end

function plot_arrival_delay_boxplot_by_airline(df, lower, upper, plot_dir)
    df_box = filter(:arr_delay => d -> !ismissing(d) && !isnan(d) && lower < d < upper, df)
    # Show airlines on X axis and arrival delay on Y axis
    @df df_box boxplot(:op_unique_carrier, :arr_delay; legend=false,
        ylabel="Arrival delay (min)", title="Delay Distribution by Airline",
        size=(800, 400), xrotation=60)
    savefig(plot_filename("7_boxplot_by_airline", plot_dir))
end

function plot_departure_vs_arrival_scatter(df, lower, upper, sample_size, plot_dir)
    Random.seed!(123)
    sample_size = min(nrow(df), sample_size)
    sample_idx = shuffle(1:nrow(df))[1:sample_size]
    dfs = df[sample_idx, :]
    dfs = filter(row ->
        !ismissing(row.arr_delay) && !ismissing(row.dep_delay) &&
        lower < row.arr_delay < upper && lower < row.dep_delay < upper,
    dfs)
    scatter(dfs.dep_delay, dfs.arr_delay; alpha=0.3, markersize=2.5,
        xlabel="Departure Delay", ylabel="Arrival Delay",
        title="Departure vs Arrival Delay (Sample)", grid=true, size=(600, 600))
    savefig(plot_filename("8_scatter_dep_arr", plot_dir))
end

function plot_average_delay_reason_stack(df, ccount, plot_dir)
    top10 = first(ccount.op_unique_carrier, min(10, length(ccount.op_unique_carrier)))
    df10 = filter(:op_unique_carrier => c -> !ismissing(c) && c in top10, df)
    c9 = combine(groupby(df10, :op_unique_carrier),
        :carrier_delay => (mean ∘ skipmissing) => :Carrier,
        :weather_delay => (mean ∘ skipmissing) => :Weather,
        :nas_delay => (mean ∘ skipmissing) => :NAS,
        :security_delay => (mean ∘ skipmissing) => :Security,
        :late_aircraft_delay => (mean ∘ skipmissing) => :LateAircraft,
    )
    labels9 = c9.op_unique_carrier
    values = Matrix(select(c9, Not(:op_unique_carrier)))
    bar(labels9, values;
        label=names(c9)[2:end], xlabel="", ylabel="Avg minutes",
        title="Delay Reason Composition (Top 10 Airlines)", stacked=true,
        size=(800, 500), xrotation=45)
    savefig(plot_filename("9_stacked_delay_reasons", plot_dir))
end

function plot_worst_average_delay_routes(df, cfg, plot_dir)
    df_routes = filter(:arr_delay => d -> !ismissing(d) && !(d isa AbstractFloat && isnan(d)), df)
    c10 = combine(groupby(df_routes, [:origin, :dest]),
        nrow => :flight_count,
        :arr_delay => (mean ∘ skipmissing) => :mean_delay,
    )
    c10 = filter(:flight_count => c -> c >= cfg.plots.route_min_flights, c10)
    sort!(c10, :mean_delay, rev=true)
    top15 = first(c10, min(15, nrow(c10)))
    top15.route = string.(top15.origin, " → ", top15.dest)
    bar(top15.route, top15.mean_delay; xlabel="", ylabel="Avg arrival delay (min)",
        title="Top 15 Worst Routes (min $(cfg.plots.route_min_flights) flights)",
        legend=false, size=(200, 700), xrotation=60,
        yticks=0:100:ceil(Int, maximum(top15.mean_delay) + 100))
    savefig(plot_filename("10_worst_routes", plot_dir))
end

function plot_delay_rate_heatmap(df, plot_dir)
    ensure_hour_features!(df)
    if !hascol(df, :is_delayed)
        if hascol(df, :arr_delay)
            df.is_delayed = coalesce.(df.arr_delay .>= 15, false)
        else
            df.is_delayed = fill(false, nrow(df))
        end
    end
    df.day_of_week = dayofweek.(df.fl_date)
    c11 = combine(groupby(df, [:day_of_week, :hour_of_day]), :is_delayed => (mean ∘ skipmissing) => :delay_rate)
    days = 1:7; hours = 0:23
    # Fill the day/hour grid so heatmap always renders a full matrix
    template = DataFrame(day_of_week=repeat(collect(days), inner=length(hours)),
                         hour_of_day=repeat(collect(hours), outer=length(days)))
    c11_complete = leftjoin(template, c11, on=[:day_of_week, :hour_of_day])
    wide11 = unstack(c11_complete, :day_of_week, :hour_of_day, :delay_rate)
    plotmat = Matrix(wide11[!, 2:end])
    heatmap(0:23, ["Mon","Tue","Wed","Thu","Fri","Sat","Sun"], plotmat';
        xlabel="Hour", ylabel="Day", title="Delay Rate by Day & Hour",
        colorbar_title="Delay rate", size=(800, 400))
    savefig(plot_filename("11_heatmap", plot_dir))
end

function plot_delay_by_hour_facets(df, ccount, plot_dir)
    top8 = first(ccount.op_unique_carrier, min(8, length(ccount.op_unique_carrier)))
    df8 = filter(:op_unique_carrier => c -> !ismissing(c) && c in top8, df)
    c12 = combine(groupby(df8, [:op_unique_carrier, :hour_of_day]), :arr_delay => (mean ∘ skipmissing) => :mean_delay)
    sort!(c12, [:op_unique_carrier, :hour_of_day])
    plots = []
    for carrier in top8
        subset = filter(:op_unique_carrier => c -> c == carrier, c12)
        p = plot(subset.hour_of_day, subset.mean_delay; marker=:circle, title=String(carrier),
            xlabel="Hour", ylabel="Avg delay", grid=true)
        push!(plots, p)
    end
    l = @layout [a b; c d; e f; g h]
    plt = plot(plots...; layout=l, size=(1000, 1000), title="Delay by Hour (Top 8 Airlines)")
    savefig(plot_filename("12_facet_airline_hour", plot_dir))
end

function generate_plots(cfg::Config, df_in::DataFrame=nothing)
    gr()

    df = if df_in === nothing
        clean_file = cfg.data.cleaned_file
        isfile(clean_file) || error("Cleaned file not found. Run Phase 2 first. Expected at $clean_file")
        @info "Loading cleaned dataset" clean_file
        @time CSV.read(clean_file, DataFrame)
    else
        df_in
    end
    ensure_date_column!(df)
    enrich_features!(df)

    plot_dir = cfg.plots.dir
    mkpath(plot_dir)

    lower = cfg.plots.delay_lower
    upper = cfg.plots.delay_upper

    @info "Generating plots" output_dir = plot_dir

    plot_arrival_delay_histogram(df, lower, upper, plot_dir)
    plot_flight_counts_by_airline(df, plot_dir)
    plot_top_busiest_airports(df, plot_dir)
    plot_cancellation_reason_counts(df, plot_dir)
    plot_average_delay_by_hour(df, plot_dir)
    plot_average_delay_by_airline(df, plot_dir)
    plot_arrival_delay_boxplot_by_airline(df, lower, upper, plot_dir)
    plot_departure_vs_arrival_scatter(df, lower, upper, cfg.plots.scatter_sample_size, plot_dir)

    ccount = combine(groupby(df, :op_unique_carrier), nrow => :flight_count)
    sort!(ccount, :flight_count, rev=true)

    plot_average_delay_reason_stack(df, ccount, plot_dir)
    plot_worst_average_delay_routes(df, cfg, plot_dir)
    plot_delay_rate_heatmap(df, plot_dir)
    plot_delay_by_hour_facets(df, ccount, plot_dir)

    @info "All plots saved" plot_dir
    df
end
