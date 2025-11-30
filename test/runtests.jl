using Test
using FlightEDA

@testset "Config loading" begin
    cfg = FlightEDA.load_config()
    @test isa(cfg, FlightEDA.Config)
    @test !isempty(cfg.data.raw_file)
    @test cfg.plots.delay_lower < cfg.plots.delay_upper
end

@testset "Utilities" begin
    @test FlightEDA.get_hour(1230) == 12
    @test FlightEDA.get_hour("0815") == 8
    @test FlightEDA.assign_time_of_day(7) == "Morning"
    @test FlightEDA.assign_time_of_day(13) == "Afternoon"
    @test FlightEDA.assign_time_of_day(18) == "Evening"
    @test FlightEDA.assign_time_of_day(2) == "Night/Red-eye"
end

@testset "Schema validation" begin
    df = DataFrame(f1=[1], f2=[2])
    @test_throws ErrorException FlightEDA.validate_schema(df)
end

@testset "CLI parsing" begin
    phase, cfg_path = FlightEDA.parse_cli_args(["--phase", "2"])
    @test phase == :phase2
    @test cfg_path == FlightEDA.DEFAULT_CONFIG_PATH

    phase, cfg_path = FlightEDA.parse_cli_args(["--phase", "smoke", "--config", "foo.toml"])
    @test phase == :smoke
    @test cfg_path == "foo.toml"
end

@testset "Cleaning and features" begin
    fixture = joinpath(@__DIR__, "fixtures", "sample.csv")
    cfg = FlightEDA.Config(
        FlightEDA.DataConfig(fixture, joinpath(@__DIR__, "fixtures", "sample_clean.csv"), fixture),
        FlightEDA.PlotConfig(joinpath(@__DIR__, "fixtures", "plots"), 1000, 1, -60.0, 180.0),
        Logging.Info,
    )
    df_clean = FlightEDA.clean_and_engineer_data(cfg)
    @test nrow(df_clean) == 3  # cancelled row stays
    @test all(!ismissing.(df_clean.carrier_delay))
    @test all(df_clean.cancellation_code .!= missing)
    @test :hour_of_day in names(df_clean)
    @test :time_of_day in names(df_clean)
    @test :is_delayed in names(df_clean)
end

@testset "Plot generation" begin
    fixture = joinpath(@__DIR__, "fixtures", "sample.csv")
    plot_dir = mktempdir()
    cfg = FlightEDA.Config(
        FlightEDA.DataConfig(fixture, joinpath(@__DIR__, "fixtures", "sample_clean.csv"), fixture),
        FlightEDA.PlotConfig(plot_dir, 1000, 1, -60.0, 180.0),
        Logging.Info,
    )
    FlightEDA.clean_and_engineer_data(cfg)
    FlightEDA.generate_plots(cfg)
    files = readdir(plot_dir)
    @test length(files) >= 10
end
