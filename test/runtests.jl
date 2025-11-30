# Import the Test package to create and run tests.
using Test
using DataFrames
using Logging
# Import the FlightEDA module, which contains the code to be tested.
using FlightEDA

# Define a test set for "Config loading". Test sets group related tests.
@testset "Config loading" begin
    # Load the configuration using a function from the FlightEDA module.
    cfg = FlightEDA.load_config()
    # Test if the loaded configuration `cfg` is of the type `FlightEDA.Config`.
    @test isa(cfg, FlightEDA.Config)
    # Test to ensure that the raw data file path in the config is not empty.
    @test !isempty(cfg.data.raw_file)
    # Test if the lower bound for plot delays is less than the upper bound.
    @test cfg.plots.delay_lower < cfg.plots.delay_upper
end

# Define a test set for "Utilities".
@testset "Utilities" begin
    # Test the `get_hour` function with an integer input.
    @test FlightEDA.get_hour(1230) == 12
    # Test the `get_hour` function with a string input.
    @test FlightEDA.get_hour("0815") == 8
    # Test the `assign_time_of_day` function for "Morning".
    @test FlightEDA.assign_time_of_day(7) == "Morning"
    # Test the `assign_time_of_day` function for "Afternoon".
    @test FlightEDA.assign_time_of_day(13) == "Afternoon"
    # Test the `assign_time_of_day` function for "Evening".
    @test FlightEDA.assign_time_of_day(18) == "Evening"
    # Test the `assign_time_of_day` function for "Night/Red-eye".
    @test FlightEDA.assign_time_of_day(2) == "Night/Red-eye"
end

# Define a test set for "Schema validation".
@testset "Schema validation" begin
    # Create a dummy DataFrame with incorrect column names.
    df = DataFrame(f1=[1], f2=[2])
    # Test that `validate_schema` throws an error for a DataFrame with an invalid schema.
    # `DataFrame` is not defined in this scope, so this test might need adjustment
    # depending on where `DataFrame` is expected to come from (e.g., using DataFrames).
    # Assuming `DataFrame` is available in the `FlightEDA` module's context.
    @test_throws ErrorException FlightEDA.validate_schema(df)
end

# Define a test set for "CLI parsing".
@testset "CLI parsing" begin
    # Test parsing command-line arguments for phase 2.
    phase, cfg_path = FlightEDA.parse_cli_args(["--phase", "2"])
    # Check if the phase is correctly identified as :phase2.
    @test phase == :phase2
    # Check if the config path is the default path when not provided.
    @test cfg_path == FlightEDA.DEFAULT_CONFIG_PATH

    # Test parsing command-line arguments for the smoke test with a custom config file.
    phase, cfg_path = FlightEDA.parse_cli_args(["--phase", "smoke", "--config", "foo.toml"])
    # Check if the phase is correctly identified as :smoke.
    @test phase == :smoke
    # Check if the config path is correctly identified as "foo.toml".
    @test cfg_path == "foo.toml"
end

# Define a test set for "Cleaning and features".
@testset "Cleaning and features" begin
    # Define the path to a sample CSV file used as a test fixture.
    fixture = joinpath(@__DIR__, "fixtures", "sample.csv")
    temp_dir = mktempdir()
    clean_path = joinpath(temp_dir, "sample_clean.csv")
    plot_dir = joinpath(temp_dir, "plots")
    # Create a configuration object for testing, pointing to test-specific paths.
    cfg = FlightEDA.Config(
        FlightEDA.DataConfig(fixture, clean_path, fixture),
        FlightEDA.PlotConfig(plot_dir, 1000, 1, 10, -60.0, 180.0),
        Logging.Info,
    )
    # Run the data cleaning and feature engineering function.
    df_clean = FlightEDA.clean_and_engineer_data(cfg)
    # Test that the resulting DataFrame has 2 rows (cancelled row is dropped).
    @test nrow(df_clean) == 2
    # Test that all values in the 'carrier_delay' column are not missing.
    @test all(.!ismissing.(df_clean.carrier_delay))
    # Test that all values in the 'cancellation_code' column are not 'missing'.
    @test all(.!ismissing.(df_clean.cancellation_code))
    # Test that the feature columns were added (compare to Symbol names).
    colsyms = Symbol.(names(df_clean))
    @test :hour_of_day in colsyms
    @test :time_of_day in colsyms
    @test :is_delayed in colsyms
end

# Define a test set for "Plot generation".
@testset "Plot generation" begin
    # Define the path to a sample CSV file used as a test fixture.
    fixture = joinpath(@__DIR__, "fixtures", "sample.csv")
    # Create a temporary directory for plot output to avoid cluttering the project.
    plot_dir = mktempdir()
    clean_path = joinpath(plot_dir, "sample_clean.csv")
    # Create a configuration object for testing, pointing to the temporary plot directory.
    cfg = FlightEDA.Config(
        FlightEDA.DataConfig(fixture, clean_path, fixture),
        FlightEDA.PlotConfig(plot_dir, 1000, 1, 10, -60.0, 180.0),
        Logging.Info,
    )
    # Run the data cleaning and feature engineering function to prepare data for plotting.
    df_clean = FlightEDA.clean_and_engineer_data(cfg)
    # Run the plot generation function.
    FlightEDA.generate_plots(cfg, df_clean)
    # Read the list of files in the plot directory.
    files = readdir(plot_dir)
    # Test that at least 10 plot files were generated.
    @test length(files) >= 10
end
