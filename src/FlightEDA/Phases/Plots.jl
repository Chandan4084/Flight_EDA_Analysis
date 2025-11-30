function run_phase3(cfg::Config, df::DataFrame=nothing)
    generate_plots(cfg, df)
    @info "Phase 3 complete"
end
