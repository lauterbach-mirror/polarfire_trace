create_and_configure_core -core_vlnv {Actel:Simulation:CLK_GEN:1.0.1} -component_name {clk_gen_refclk} -params "\"CLK_PERIOD:8000\"  \"DUTY_CYCLE:50\""
create_and_configure_core -core_vlnv {Actel:Simulation:CLK_GEN:1.0.1} -component_name {clk_gen_ref_50MHz} -params "\"CLK_PERIOD:20000\"  \"DUTY_CYCLE:50\""
