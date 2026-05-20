# Target 200 MHz — tighter than achievable to expose the critical path.
# Check "Slow 1200mV 85C" Fmax in the Timing Analyzer report.
create_clock -period "200.0 MHz" [get_ports clk]

derive_clock_uncertainty
