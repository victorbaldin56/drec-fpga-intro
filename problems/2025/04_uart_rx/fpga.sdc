create_clock -period "50.0 MHz" [get_ports CLK]

derive_clock_uncertainty

set_false_path -from RXD  -to [all_clocks]
set_false_path -from RSTN -to [all_clocks]
set_false_path -from * -to [get_ports {DS OE SHCP STCP}]
