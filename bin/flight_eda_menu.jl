#!/usr/bin/env julia

# Interactive CLI to run phases and view quick summaries/plot locations.

using Logging

const SRC_DIR = abspath(joinpath(@__DIR__, "..", "src"))
Base.include(Main, joinpath(SRC_DIR, "FlightEDA.jl"))
using .FlightEDA

function ensure_instantiated()
    project_path = abspath(joinpath(@__DIR__, "..", "Project.toml"))
    manifest_path = abspath(joinpath(@__DIR__, "..", "Manifest.toml"))
    if !(isfile(project_path) && isfile(manifest_path))
        println("Project not instantiated. Run:")
        println("  JULIA_DEPOT_PATH=./.julia_depot ./julia-1.10.5/bin/julia --project=. -e 'using Pkg; Pkg.instantiate()'")
        exit(1)
    end
end

function prompt(msg::String; default::Union{Nothing,String}=nothing)
    print(default === nothing ? "$msg: " : "$msg [$default]: ")
    flush(stdout)
    inp = readline(stdin)
    isempty(inp) && default !== nothing ? default : strip(inp)
end

function load_cfg()
    cfg_path = prompt("Config path", default=get(ENV, "EDA_CONFIG", FlightEDA.DEFAULT_CONFIG_PATH))
    cfg = FlightEDA.load_config(cfg_path)
    global_logger(ConsoleLogger(stderr, cfg.log_level))
    return cfg
end

function show_plot_list(plot_dir::String)
    if !isdir(plot_dir)
        println("No plots directory found at $plot_dir. Run phase 3 first.")
        return
    end
    files = sort(filter(f -> endswith(f, ".png"), readdir(plot_dir)))
    isempty(files) && println("No plot files found in $plot_dir")
    for f in files
        println(" - $(joinpath(plot_dir, f))")
    end
end

function open_plot(plot_dir::String)
    if !isdir(plot_dir)
        println("No plots directory found at $plot_dir. Run phase 3 first.")
        return
    end
    files = sort(filter(f -> endswith(f, ".png"), readdir(plot_dir)))
    if isempty(files)
        println("No plot files found in $plot_dir")
        return
    end
    println("Select a plot to open:")
    for (i, f) in enumerate(files)
        println(" $(i)) $f")
    end
    choice = prompt("Enter number (or blank to cancel)", default="")
    isempty(choice) && return
    idx = tryparse(Int, choice)
    if idx === nothing || idx < 1 || idx > length(files)
        println("Invalid selection.")
        return
    end
    plot_path = abspath(joinpath(plot_dir, files[idx]))
    println("Opening $plot_path ...")
    cmd = if Sys.isapple()
        `open $plot_path`
    elseif Sys.iswindows()
        `cmd /c start "" $plot_path`
    else
        `xdg-open $plot_path`
    end
    try
        run(cmd)
    catch err
        println("Failed to open plot: $err")
    end
end

function show_quick_stats(cfg::Config)
    clean_path = cfg.data.cleaned_file
    if !isfile(clean_path)
        println("Cleaned file not found at $clean_path. Run phase 2 first.")
        return
    end
    df = CSV.read(clean_path, DataFrame)
    ensure_date_column!(df)
    enrich_features!(df)
    on_time = mean(skipmissing(df.arr_delay .<= 15))
    mean_arr = mean(skipmissing(df.arr_delay))
    peak = combine(groupby(df, :hour_of_day), :arr_delay => (mean ∘ skipmissing) => :mean_delay)
    sort!(peak, :mean_delay, rev=true)
    worst_hour = first(peak, 1)
    routes = combine(groupby(df, [:origin, :dest]), nrow => :flight_count, :arr_delay => (mean ∘ skipmissing) => :mean_delay)
    routes = filter(:flight_count => c -> c >= 50, routes)
    sort!(routes, :mean_delay, rev=true)
    println("=== Quick stats ===")
    println("On-time share (<=15 min): $(round(on_time*100, digits=2))%")
    println("Mean arrival delay: $(round(mean_arr, digits=2)) min")
    if nrow(worst_hour) > 0
        println("Peak delay hour: $(worst_hour.hour_of_day[1]) (mean $(round(worst_hour.mean_delay[1], digits=2)) min)")
    end
    if nrow(routes) > 0
        top = first(routes, 3)
        println("Worst routes (avg delay, >=50 flights):")
        for r in eachrow(top)
            println(" - $(r.origin) → $(r.dest): $(round(r.mean_delay, digits=2)) min (n=$(r.flight_count))")
        end
    end
end

function run_option(cfg::Config, choice::String)
    # Define a dictionary of actions
    actions = Dict{String, Function}(
        "1" => () -> FlightEDA.run_phase(:phase1, cfg),
        "2" => () -> FlightEDA.run_phase(:phase2, cfg),
        "3" => () -> FlightEDA.run_phase(:phase3, cfg),
        "all" => () -> FlightEDA.run_phase(:all, cfg),
        "smoke" => () -> FlightEDA.run_phase(:smoke, cfg),
        "plots" => () -> show_plot_list(cfg.plots.dir),
        "open" => () -> open_plot(cfg.plots.dir),
        "stats" => () -> show_quick_stats(cfg)
    )

    if haskey(actions, choice)
        actions[choice]()
    elseif choice == "config"
        cfg = load_cfg()
        return cfg
    elseif choice == "q"
        println("Bye.")
        exit(0)
    else
        println("Unknown choice.")
    end
    return cfg
end

function menu()
    ensure_instantiated()
    cfg = load_cfg()
    while true
        println("\n=== FlightEDA menu ===")
        println(" 1) Phase 1 – load/describe")
        println(" 2) Phase 2 – clean/features")
        println(" 3) Phase 3 – plots")
        println(" all) Run all phases")
        println(" smoke) Smoke test")
        println(" stats) Quick stats from cleaned data")
        println(" plots) List plot files")
        println(" open) Open a plot file")
        println(" config) Reload config")
        println(" q) Quit")
        choice = String(prompt("Select option", default=""))
        cfg = run_option(cfg, choice)
    end
end

if abspath(PROGRAM_FILE) == @__FILE__
    menu()
end
