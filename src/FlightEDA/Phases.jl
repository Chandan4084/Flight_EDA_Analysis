include("Phases/Load.jl")
include("Phases/Clean.jl")
include("Phases/Plots.jl")

function run_phase(phase::Symbol, cfg::Config)
    if phase === :phase1
        run_load_phase(cfg)
    elseif phase === :phase2
        run_clean_phase(cfg)
    elseif phase === :phase3
        # Load cleaned data if running phase 3 standalone
        clean_file = cfg.data.cleaned_file
        isfile(clean_file) || error("Cleaned file not found. Run Phase 2 first. Expected at $clean_file")
        @info "Loading cleaned dataset for plotting" clean_file
        df = CSV.read(clean_file, DataFrame)
        run_phase3(cfg, df)
    elseif phase === :all
        df1 = run_load_phase(cfg)
        df2 = run_clean_phase(cfg)
        # Pass the cleaned dataframe directly to phase 3
        run_phase3(cfg, df2)
        return df1, df2 # Or just df2
    elseif phase === :smoke
        run_smoke(cfg)
    else
        error("Unknown phase: $phase")
    end
end
