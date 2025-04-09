if {$variant == "2lane"} {
	set lanes [list "0" "1"]
	set period_lane 2000
	set period_byte 1000
	set gLanes 2
	set gBytesPerLane 2
} else {
	set lanes [list "0"]
	set period_lane 1000
	set period_byte 1000
	set gLanes 1
	set gBytesPerLane 4
}

source $board_path/cr/3_create_sim_cores.tcl
create_and_configure_core -core_vlnv {Actel:Simulation:CLK_GEN:1.0.1} -component_name {clk_gen_pcie_refclk} -params "\"CLK_PERIOD:10000\"  \"DUTY_CYCLE:50\""
create_and_configure_core -core_vlnv {Actel:Simulation:CLK_GEN:1.0.1} -component_name {clk_gen_lane} -params  "\"CLK_PERIOD:$period_lane\"  \"DUTY_CYCLE:50\""
create_and_configure_core -core_vlnv {Actel:Simulation:CLK_GEN:1.0.1} -component_name {clk_gen_byte} -params  "\"CLK_PERIOD:$period_byte\"  \"DUTY_CYCLE:50\""
create_and_configure_core -core_vlnv {Actel:Simulation:RESET_GEN:1.0.1} -component_name {reset_gen_c0} -params "\"DELAY:100\" \"LOGIC_LEVEL:1\""

source $src_path/aurora_dummy_xcvr_$variant.tcl

set sd_name "trace_top_aurora_tb"
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
sd_instantiate_component -sd_name $sd_name -component_name {clk_gen_pcie_refclk} -instance_name {clk_gen_pcie_refclk_0}
sd_instantiate_component -sd_name $sd_name -component_name {clk_gen_lane} -instance_name {clk_gen_lane_0}
sd_instantiate_component -sd_name $sd_name -component_name {clk_gen_byte} -instance_name {clk_gen_byte_0}
sd_instantiate_component -sd_name $sd_name -component_name {reset_gen_c0} -instance_name {reset_gen_c0_0}

# Add verification instances
sd_instantiate_component -sd_name $sd_name -component_name "aurora_dummy_xcvr_$variant" -instance_name {aurora_dummy_xcvr_0}
sd_instantiate_hdl_core -sd_name $sd_name -hdl_core_name {sim_aurora_rx} -instance_name {sim_aurora_rx_0}
sd_configure_core_instance -sd_name $sd_name -instance_name {sim_aurora_rx_0} -params "\"gLanes:$gLanes\" \"gBytesPerLane:$gBytesPerLane\"" -validate_rules 0
sd_save_core_instance_config -sd_name $sd_name -instance_name {sim_aurora_rx_0}
sd_update_instance -sd_name $sd_name -instance_name {sim_aurora_rx_0}
sd_instantiate_hdl_core -sd_name $sd_name -hdl_core_name {sim_check_against_bfm} -instance_name {sim_check_against_bfm_0}
sd_configure_core_instance -sd_name $sd_name -instance_name {sim_check_against_bfm_0} -params "\"gSequenceLength:1536\"" -validate_rules 0
sd_save_core_instance_config -sd_name $sd_name -instance_name {sim_check_against_bfm_0}
sd_update_instance -sd_name $sd_name -instance_name {sim_check_against_bfm_0}

# Add UUT instance
sd_instantiate_component -sd_name $sd_name -component_name {trace_top_aurora} -instance_name {trace_top_aurora_0}

# UUT -> decoder connections via dummy receiver
foreach lane $lanes {
	set sl_lane "\[$lane:$lane\]"
	set sl_bit  "\[[expr ($lane + 1) * $gBytesPerLane - 1]:[expr $lane * $gBytesPerLane]\]"
	set sl_byte "\[[expr ($lane + 1) * 8 * $gBytesPerLane - 1]:[expr $lane * 8 * $gBytesPerLane]\]"

	sd_invert_pins -sd_name $sd_name -pin_names "aurora_dummy_xcvr_0:LANE${lane}_PCS_ARST_N"
	sd_invert_pins -sd_name $sd_name -pin_names "aurora_dummy_xcvr_0:LANE${lane}_PMA_ARST_N"

	sd_create_pin_slices -sd_name $sd_name -pin_name "sim_aurora_rx_0:iRxClk"            -pin_slices "$sl_lane"
	sd_create_pin_slices -sd_name $sd_name -pin_name "sim_aurora_rx_0:iRxData"           -pin_slices "$sl_byte"
	sd_create_pin_slices -sd_name $sd_name -pin_name "sim_aurora_rx_0:iRxK"              -pin_slices "$sl_bit"
	sd_create_pin_slices -sd_name $sd_name -pin_name "sim_aurora_rx_0:iRxCodeViolation"  -pin_slices "$sl_bit"
	sd_create_pin_slices -sd_name $sd_name -pin_name "sim_aurora_rx_0:iRxDisparityError" -pin_slices "$sl_bit"
	sd_create_pin_slices -sd_name $sd_name -pin_name "sim_aurora_rx_0:iRxReady"          -pin_slices "$sl_lane"
	sd_create_pin_slices -sd_name $sd_name -pin_name "sim_aurora_rx_0:iRxVal"            -pin_slices "$sl_lane"

	sd_connect_pins -sd_name $sd_name -pin_names "\"clk_gen_refclk_0:CLK\" \"aurora_dummy_xcvr_0:LANE${lane}_CDR_REF_CLK_0\""
	sd_connect_pins -sd_name $sd_name -pin_names "\"reset_gen_c0_0:RESET\" \"aurora_dummy_xcvr_0:LANE${lane}_PCS_ARST_N\""
	sd_connect_pins -sd_name $sd_name -pin_names "\"reset_gen_c0_0:RESET\" \"aurora_dummy_xcvr_0:LANE${lane}_PMA_ARST_N\""

	sd_connect_pins -sd_name $sd_name -pin_names "\"trace_top_aurora_0:FMC_DP${lane}_TXD_N\" \"aurora_dummy_xcvr_0:LANE${lane}_RXD_N\""
	sd_connect_pins -sd_name $sd_name -pin_names "\"trace_top_aurora_0:FMC_DP${lane}_TXD_P\" \"aurora_dummy_xcvr_0:LANE${lane}_RXD_P\""

	sd_connect_pins -sd_name $sd_name -pin_names "\"sim_aurora_rx_0:iRxClk$sl_lane\" \"aurora_dummy_xcvr_0:LANE${lane}_RX_CLK_R\""
	sd_connect_pins -sd_name $sd_name -pin_names "\"sim_aurora_rx_0:iRxData$sl_byte\" \"aurora_dummy_xcvr_0:LANE${lane}_RX_DATA\""
	sd_connect_pins -sd_name $sd_name -pin_names "\"sim_aurora_rx_0:iRxK$sl_bit\" \"aurora_dummy_xcvr_0:LANE${lane}_8B10B_RX_K\""
	sd_connect_pins -sd_name $sd_name -pin_names "\"sim_aurora_rx_0:iRxCodeViolation$sl_bit\" \"aurora_dummy_xcvr_0:LANE${lane}_RX_CODE_VIOLATION\""
	sd_connect_pins -sd_name $sd_name -pin_names "\"sim_aurora_rx_0:iRxDisparityError$sl_bit\" \"aurora_dummy_xcvr_0:LANE${lane}_RX_DISPARITY_ERROR\""
	sd_connect_pins -sd_name $sd_name -pin_names "\"sim_aurora_rx_0:iRxReady$sl_lane\" \"aurora_dummy_xcvr_0:LANE${lane}_RX_READY\""
	sd_connect_pins -sd_name $sd_name -pin_names "\"sim_aurora_rx_0:iRxVal$sl_lane\" \"aurora_dummy_xcvr_0:LANE${lane}_RX_VAL\""
	sd_mark_pins_unused -sd_name $sd_name -pin_names "aurora_dummy_xcvr_0:LANE${lane}_RX_IDLE"
}

# clock/reset connections
sd_invert_pins -sd_name $sd_name -pin_names {trace_top_aurora_0:REFCLK_N}
sd_invert_pins -sd_name $sd_name -pin_names {trace_top_aurora_0:REF_CLK_PAD_N}
sd_invert_pins -sd_name $sd_name -pin_names {trace_top_aurora_0:PCIE_REFCLK_N}
sd_connect_pins -sd_name $sd_name -pin_names {"clk_gen_refclk_0:CLK" "trace_top_aurora_0:REFCLK" "trace_top_aurora_0:REFCLK_N"}
sd_connect_pins -sd_name $sd_name -pin_names {"clk_gen_ref_clk_pad_0:CLK" "trace_top_aurora_0:REF_CLK_PAD_N" "trace_top_aurora_0:REF_CLK_PAD_P"}
sd_connect_pins -sd_name $sd_name -pin_names {"clk_gen_pcie_refclk_0:CLK" "trace_top_aurora_0:PCIE_REFCLK_N" "trace_top_aurora_0:PCIE_REFCLK_P"}
sd_connect_pins -sd_name $sd_name -pin_names {"reset_gen_c0_0:RESET" "sim_aurora_rx_0:iRst" }
sd_connect_pins -sd_name $sd_name -pin_names {"clk_gen_lane_0:CLK" "sim_check_against_bfm_0:iClkByte" "sim_aurora_rx_0:iClkLane" }
sd_connect_pins -sd_name $sd_name -pin_names {"clk_gen_byte_0:CLK" "sim_check_against_bfm_0:iClkByte" "sim_aurora_rx_0:iClkByte" }

# decoder -> verifier connections
sd_connect_pins -sd_name $sd_name -pin_names {"sim_check_against_bfm_0:iValid" "sim_aurora_rx_0:oValid"}
sd_connect_pins -sd_name $sd_name -pin_names {"sim_check_against_bfm_0:iData" "sim_aurora_rx_0:oData"}

# verifier -> output
sd_connect_pins -sd_name $sd_name -pin_names {"oDone" "sim_check_against_bfm_0:oDone"}

# DDR connections
sd_connect_pins -sd_name $sd_name -pin_names {"CK" "trace_top_aurora_0:CK" }
sd_connect_pins -sd_name $sd_name -pin_names {"CKE" "trace_top_aurora_0:CKE" }
sd_connect_pins -sd_name $sd_name -pin_names {"CK_N" "trace_top_aurora_0:CK_N" }
sd_connect_pins -sd_name $sd_name -pin_names {"CS" "trace_top_aurora_0:CS" }
sd_connect_pins -sd_name $sd_name -pin_names {"ODT" "trace_top_aurora_0:ODT" }
sd_connect_pins -sd_name $sd_name -pin_names {"RESET_N" "trace_top_aurora_0:RESET_N" }
sd_connect_pins -sd_name $sd_name -pin_names {"CA" "trace_top_aurora_0:CA" }
sd_connect_pins -sd_name $sd_name -pin_names {"DM" "trace_top_aurora_0:DM" }
sd_connect_pins -sd_name $sd_name -pin_names {"DQ" "trace_top_aurora_0:DQ" }
sd_connect_pins -sd_name $sd_name -pin_names {"DQS" "trace_top_aurora_0:DQS" }
sd_connect_pins -sd_name $sd_name -pin_names {"DQS_N" "trace_top_aurora_0:DQS_N" }

# Re-enable auto promotion of pins of type 'pad'
auto_promote_pad_pins -promote_all 1
save_smartdesign -sd_name $sd_name
generate_component -component_name $sd_name

source $src_path/simulation_options.tcl
