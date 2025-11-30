#!/usr/bin/env julia

# This script provides an interactive command-line interface (CLI) menu 
# to run different phases of the flight data analysis, view summaries, and open plots.

# Import the Logging module to handle log messages.
using Logging

# Define the absolute path to the 'src' directory, which contains the main project code.
const SRC_DIR = abspath(joinpath(@__DIR__, "..", "src"))
# Include and execute the main project file, making its modules and functions available.
Base.include(Main, joinpath(SRC_DIR, "FlightEDA.jl"))
# Make the FlightEDA module available in the current scope.
using .FlightEDA

# This function checks if the project dependencies are installed (instantiated).
# If not, it prints instructions on how to install them.
function ensure_instantiated()
    project_path = abspath(joinpath(@__DIR__, "..", "Project.toml"))
    manifest_path = abspath(joinpath(@__DIR__, "..", "Manifest.toml"))
    # Check if Project.toml and Manifest.toml files exist.
    if !(isfile(project_path) && isfile(manifest_path))
        println("Project not instantiated. Run:")
        println("  JULIA_DEPOT_PATH=./.julia_depot ./julia-1.10.5/bin/julia --project=. -e 'using Pkg; Pkg.instantiate()'")
        exit(1) # Exit the script if dependencies are not met.
    end
end

# This function displays a message to the user and waits for their input.
# It can also provide a default value if the user just presses Enter.
function prompt(msg::String; default::Union{Nothing,String}=nothing)
    # Display the message, including the default value if one is provided.
    print(default === nothing ? "$msg: " : "$msg [$default]: ")
    flush(stdout) # Ensure the message is displayed immediately.
    inp = readline(stdin) # Read the user's input from the console.
    # If the input is empty and a default value exists, return the default. Otherwise, return the stripped input.
    isempty(inp) && default !== nothing ? default : strip(inp)
end

# This function loads the configuration from a TOML file.
# It prompts the user for the config file path, with a default value.
function load_cfg()
    cfg_path = prompt("Config path", default=get(ENV, "EDA_CONFIG", FlightEDA.DEFAULT_CONFIG_PATH))
    # Load the configuration using a function from the FlightEDA module.
    cfg = FlightEDA.load_config(cfg_path)
    # Set up a global logger to show messages based on the log level in the config.
    global_logger(ConsoleLogger(stderr, cfg.log_level))
    return cfg # Return the loaded configuration object.
end

# This function lists all the generated plot files (.png) in the specified directory.
function show_plot_list(plot_dir::String)
    # Check if the plot directory exists.
    if !isdir(plot_dir)
        println("No plots directory found at $plot_dir. Run phase 3 first.")
        return
    end
    # Get a sorted list of all files ending with ".png".
    files = sort(filter(f -> endswith(f, ".png"), readdir(plot_dir)))
    # Inform the user if no plots are found.
    isempty(files) && println("No plot files found in $plot_dir")
    # Print the full path of each plot file.
    for f in files
        println(" - $(joinpath(plot_dir, f))")
    end
end

# This function allows the user to select and open a plot file using the default system viewer.
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
    # Display a numbered list of available plots.
    println("Select a plot to open:")
    for (i, f) in enumerate(files)
        println(" $(i)) $f")
    end
    # Prompt the user to make a selection.
    choice = prompt("Enter number (or blank to cancel)", default="")
    isempty(choice) && return # Cancel if the user enters nothing.
    # Parse the user's choice into a number.
    idx = tryparse(Int, choice)
    if idx === nothing || idx < 1 || idx > length(files)
        println("Invalid selection.")
        return
    end
    # Get the full path of the selected plot.
    plot_path = abspath(joinpath(plot_dir, files[idx]))
    println("Opening $plot_path ...")
    # Determine the correct command to open a file based on the operating system.
    cmd = if Sys.isapple()
        `open $plot_path` # macOS
    elseif Sys.iswindows()
        `cmd /c start "" $plot_path` # Windows
    else
        `xdg-open $plot_path` # Linux
    end
    # Try to run the command and open the file.
    try
        run(cmd)
    catch err
        println("Failed to open plot: $err") # Report any errors.
    end
end

# This function calculates and displays some quick statistics from the cleaned data.
function show_quick_stats(cfg::Config)
    clean_path = cfg.data.cleaned_file
    # Check if the cleaned data file exists.
    if !isfile(clean_path)
        println("Cleaned file not found at $clean_path. Run phase 2 first.")
        return
    end
    # Read the cleaned data from the CSV file into a DataFrame.
    df = CSV.read(clean_path, DataFrame)
    # Perform necessary data transformations.
    ensure_date_column!(df)
    enrich_features!(df)
    
    # --- Calculate Statistics ---
    # Calculate the percentage of on-time arrivals (delay <= 15 minutes).
    on_time = mean(skipmissing(df.arr_delay .<= 15))
    # Calculate the average arrival delay.
    mean_arr = mean(skipmissing(df.arr_delay))
    # Find the hour of the day with the highest average delay.
    peak = combine(groupby(df, :hour_of_day), :arr_delay => (mean ∘ skipmissing) => :mean_delay)
    sort!(peak, :mean_delay, rev=true)
    worst_hour = first(peak, 1)
    # Find the routes with the worst average delays (for routes with at least 50 flights).
    routes = combine(groupby(df, [:origin, :dest]), nrow => :flight_count, :arr_delay => (mean ∘ skipmissing) => :mean_delay)
    routes = filter(:flight_count => c -> c >= 50, routes)
    sort!(routes, :mean_delay, rev=true)

    # --- Display Statistics ---
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

# This function executes the action corresponding to the user's menu choice.
function run_option(cfg::Config, choice::String)
    # A dictionary mapping user choices to functions.
    actions = Dict{String, Function}(
        "1" => () -> FlightEDA.run_phase(:phase1, cfg),    # Run Phase 1: Load and describe data
        "2" => () -> FlightEDA.run_phase(:phase2, cfg),    # Run Phase 2: Clean and add features
        "3" => () -> FlightEDA.run_phase(:phase3, cfg),    # Run Phase 3: Generate plots
        "all" => () -> FlightEDA.run_phase(:all, cfg),      # Run all phases
        "smoke" => () -> FlightEDA.run_phase(:smoke, cfg),  # Run a quick smoke test
        "plots" => () -> show_plot_list(cfg.plots.dir),    # List all plot files
        "open" => () -> open_plot(cfg.plots.dir),        # Open a specific plot file
        "stats" => () -> show_quick_stats(cfg)             # Show quick statistics
    )

    # Check if the user's choice is a key in the actions dictionary and execute it.
    if haskey(actions, choice)
        actions[choice]()
    elseif choice == "config"
        # If the user chooses 'config', reload the configuration file.
        cfg = load_cfg()
        return cfg
    elseif choice == "q"
        # If the user chooses 'q', quit the program.
        println("Bye.")
        exit(0)
    else
        # Handle unknown choices.
        println("Unknown choice.")
    end
    return cfg
end

# This is the main function that runs the interactive menu.
function menu()
    ensure_instantiated() # First, ensure all dependencies are set up.
    cfg = load_cfg()      # Load the initial configuration.
    
    # Loop indefinitely to keep showing the menu until the user quits.
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
        
        # Prompt the user for their choice.
        choice = String(prompt("Select option", default=""))
        # Execute the chosen option and potentially update the config.
        cfg = run_option(cfg, choice)
    end
end

# This is a standard Julia construct.
# It ensures that the `menu()` function is called only when this script is executed directly.
if abspath(PROGRAM_FILE) == @__FILE__
    menu()
end
