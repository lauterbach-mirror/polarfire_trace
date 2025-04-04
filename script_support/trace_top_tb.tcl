set gBytes [expr $bits_used / 8]

# nominally 4000 / $gBytes, but make it slightly faster due to rounding errors in the clk_gen_ref_clk_pad specifications and/or the PLL
set period_byte [expr 3900 / $gBytes]

source $board_path/cr/3_create_sim_cores.tcl
create_and_configure_core -core_vlnv {Actel:Simulation:CLK_GEN:1.0.1} -component_name {clk_gen_byte} -params  "\"CLK_PERIOD:$period_byte\"  \"DUTY_CYCLE:50\""
create_and_configure_core -core_vlnv {Actel:Simulation:RESET_GEN:1.0.1} -component_name {reset_gen_c0} -params "\"DELAY:100\" \"LOGIC_LEVEL:1\""

set sd_name "trace_top_tb"
create_smartdesign_testbench -sd_name $sd_name

# Disable auto promotion of pins of type 'pad'
auto_promote_pad_pins -promote_all 0

# DDR pins
sd_create_scalar_port -sd_name $sd_name -port_name {CKE} -port_direction {OUT} -port_is_pad {1}
sd_create_scalar_port -sd_name $sd_name -port_name {CK_N} -port_direction {OUT} -port_is_pad {1}
sd_create_scalar_port -sd_name $sd_name -port_name {CK} -port_direction {OUT} -port_is_pad {1}
sd_create_scalar_port -sd_name $sd_name -port_name {CS} -port_direction {OUT} -port_is_pad {1}
sd_create_scalar_port -sd_name $sd_name -port_name {ODT} -port_direction {OUT} -port_is_pad {1}
sd_create_scalar_port -sd_name $sd_name -port_name {RESET_N} -port_direction {OUT} -port_is_pad {1}
sd_create_bus_port -sd_name $sd_name -port_name {CA} -port_direction {OUT} -port_range {[5:0]} -port_is_pad {1}
sd_create_bus_port -sd_name $sd_name -port_name {DM} -port_direction {OUT} -port_range {[3:0]} -port_is_pad {1}
sd_create_bus_port -sd_name $sd_name -port_name {DQS_N} -port_direction {INOUT} -port_range {[3:0]} -port_is_pad {1}
sd_create_bus_port -sd_name $sd_name -port_name {DQS} -port_direction {INOUT} -port_range {[3:0]} -port_is_pad {1}
sd_create_bus_port -sd_name $sd_name -port_name {DQ} -port_direction {INOUT} -port_range {[31:0]} -port_is_pad {1}

# "all OK" pin
sd_create_scalar_port -sd_name $sd_name -port_name {oDone} -port_direction {OUT}

# Add generator instances
source $board_path/cr/4_create_sim_components.tcl
sd_instantiate_component -sd_name $sd_name -component_name {clk_gen_byte} -instance_name {clk_gen_byte_0}
sd_instantiate_component -sd_name $sd_name -component_name {reset_gen_c0} -instance_name {reset_gen_c0_0}

# Add verification instances
sd_instantiate_hdl_core -sd_name $sd_name -hdl_core_name {sim_pti_rx} -instance_name {sim_pti_rx_0}
sd_configure_core_instance -sd_name $sd_name -instance_name {sim_pti_rx_0} -params "\"gBytes:$gBytes\"" -validate_rules 0
sd_save_core_instance_config -sd_name $sd_name -instance_name {sim_pti_rx_0}
sd_update_instance -sd_name $sd_name -instance_name {sim_pti_rx_0}
sd_instantiate_hdl_core -sd_name $sd_name -hdl_core_name {sim_check_against_bfm} -instance_name {sim_check_against_bfm_0}
sd_configure_core_instance -sd_name $sd_name -instance_name {sim_check_against_bfm_0} -params "\"gSequenceLength:1536\"" -validate_rules 0
sd_save_core_instance_config -sd_name $sd_name -instance_name {sim_check_against_bfm_0}
sd_update_instance -sd_name $sd_name -instance_name {sim_check_against_bfm_0}

# Add UUT instance
sd_instantiate_component -sd_name $sd_name -component_name {trace_top} -instance_name {trace_top_0}

# UUT -> decoder connections
sd_connect_pins -sd_name $sd_name -pin_names {"trace_top_0:oTraceClk" "sim_pti_rx_0:iTraceClk"}
if {$bits_used == $bits_phys} {
	sd_connect_pins -sd_name $sd_name -pin_names {"trace_top_0:oTraceData" "sim_pti_rx_0:iTraceData"}
} else {
	sd_create_pin_slices -sd_name $sd_name -pin_name "trace_top_0:oTraceData" -pin_slices "\[[expr $bits_phys - 1]:$bits_used\]"
	sd_create_pin_slices -sd_name $sd_name -pin_name "trace_top_0:oTraceData" -pin_slices "\[[expr $bits_used - 1]:0\]"
	sd_connect_pins -sd_name $sd_name -pin_names "\"trace_top_0:oTraceData\[[expr $bits_used - 1]:0\]\" \"sim_pti_rx_0:iTraceData\""
	sd_mark_pins_unused -sd_name $sd_name -pin_names "trace_top_0:oTraceData\[[expr $bits_phys - 1]:$bits_used\]"
}

# clock/reset connections
source $board_path/cr/5_connect_sim_clocks.tcl
sd_connect_pins -sd_name $sd_name -pin_names {"reset_gen_c0_0:RESET" "sim_pti_rx_0:iRst" }
sd_connect_pins -sd_name $sd_name -pin_names {"clk_gen_byte_0:CLK" "sim_check_against_bfm_0:iClkByte" "sim_pti_rx_0:iClkByte" }

# decoder -> verifier connections
sd_connect_pins -sd_name $sd_name -pin_names {"sim_check_against_bfm_0:iValid" "sim_pti_rx_0:oValid"}
sd_connect_pins -sd_name $sd_name -pin_names {"sim_check_against_bfm_0:iData" "sim_pti_rx_0:oData"}

# verifier -> output
sd_connect_pins -sd_name $sd_name -pin_names {"oDone" "sim_check_against_bfm_0:oDone"}

# DDR connections
sd_connect_pins -sd_name $sd_name -pin_names {"CK" "trace_top_0:CK" }
sd_connect_pins -sd_name $sd_name -pin_names {"CKE" "trace_top_0:CKE" }
sd_connect_pins -sd_name $sd_name -pin_names {"CK_N" "trace_top_0:CK_N" }
sd_connect_pins -sd_name $sd_name -pin_names {"CS" "trace_top_0:CS" }
sd_connect_pins -sd_name $sd_name -pin_names {"ODT" "trace_top_0:ODT" }
sd_connect_pins -sd_name $sd_name -pin_names {"RESET_N" "trace_top_0:RESET_N" }
sd_connect_pins -sd_name $sd_name -pin_names {"CA" "trace_top_0:CA" }
sd_connect_pins -sd_name $sd_name -pin_names {"DM" "trace_top_0:DM" }
sd_connect_pins -sd_name $sd_name -pin_names {"DQ" "trace_top_0:DQ" }
sd_connect_pins -sd_name $sd_name -pin_names {"DQS" "trace_top_0:DQS" }
sd_connect_pins -sd_name $sd_name -pin_names {"DQS_N" "trace_top_0:DQS_N" }

# Re-enable auto promotion of pins of type 'pad'
auto_promote_pad_pins -promote_all 1
save_smartdesign -sd_name $sd_name
generate_component -component_name $sd_name
