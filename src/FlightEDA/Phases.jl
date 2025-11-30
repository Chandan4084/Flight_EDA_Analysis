# This file brings together the different phases of the analysis.
include("Phases/Load.jl") # Contains functions for loading data
include("Phases/Clean.jl") # Contains functions for cleaning data
include("Phases/Plots.jl") # Contains functions for generating plots

# This function runs a specific phase of the analysis based on the
# provided phase symbol and configuration.
function run_phase(phase::Symbol, cfg::Config)
    if phase === :phase1
        # Run only the data loading phase.
        run_load_phase(cfg)
    elseif phase === :phase2
        # Run only the data cleaning phase.
        run_clean_phase(cfg)
    elseif phase === :phase3
        # If running only the plotting phase, first load the cleaned data.
        clean_file = cfg.data.cleaned_file
        isfile(clean_file) || error("Cleaned file not found. Run Phase 2 first. Expected at $clean_file")
        @info "Loading cleaned dataset for plotting" clean_file
        df = CSV.read(clean_file, DataFrame)
        # Then, generate the plots.
        run_phase3(cfg, df)
    elseif phase === :all
        # Run all phases in sequence.
        df1 = run_load_phase(cfg)
        df2 = run_clean_phase(cfg; df_raw=copy(df1))
        # Pass the cleaned dataframe directly to the plotting phase.
        run_phase3(cfg, df2)
        return df1, df2 # Return the dataframes from phase 1 and 2
    elseif phase === :smoke
        # Run a quick smoke test to ensure everything is working.
        run_smoke(cfg)
    else
        # If the phase is not recognized, throw an error.
        error("Unknown phase: $phase")
    end
end
