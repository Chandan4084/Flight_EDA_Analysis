module Profile

using ..FlightEDA
using ..FlightEDA.Config

"""
This function profiles the runtime and memory allocation of a given analysis phase.
"""
function run_profile(phase_str::String="all")
    # Parse the string to get the corresponding phase enum.
    phase = FlightEDA.parse_phase(phase_str)

    # Use the default configuration file for the profiling.
    cfg = FlightEDA.load_config(FlightEDA.DEFAULT_CONFIG_PATH)

    println("Profiling phase: $(phase_str)")

    # Use @time to measure the execution time and @allocated to measure memory usage.
    # The stats are printed to the console after the function call is complete.
    stats = @timed FlightEDA.run_phase(phase, cfg)

    # Print a summary of the profiling results.
    println("\n--- Profiling Summary ---")
    println("Phase: $(phase_str)")
    println("Time: $(stats.time) seconds")
    println("Memory allocated: $(Base.format_bytes(stats.bytes))")
    println("Garbage collection time: $(stats.gctime) seconds")
    println("-----------------------\n")
end

end # module Profile