set sd_name trace_top
create_smartdesign -sd_name ${sd_name}

auto_promote_pad_pins -promote_all 0

# clock pins
sd_create_scalar_port -sd_name $sd_name -port_name REFCLK_N -port_direction IN -port_is_pad 1
sd_create_scalar_port -sd_name $sd_name -port_name REFCLK -port_direction IN -port_is_pad 1
source $board_path/cr/1_create_pins.tcl

# DDR pins
sd_create_bus_port    -sd_name $sd_name -port_name CA -port_direction OUT -port_range "\[5:0}]" -port_is_pad 1
sd_create_scalar_port -sd_name $sd_name -port_name CK -port_direction OUT -port_is_pad 1
sd_create_scalar_port -sd_name $sd_name -port_name CKE -port_direction OUT -port_is_pad 1
sd_create_scalar_port -sd_name $sd_name -port_name CK_N -port_direction OUT -port_is_pad 1
sd_create_scalar_port -sd_name $sd_name -port_name CS -port_direction OUT -port_is_pad 1
sd_create_bus_port    -sd_name $sd_name -port_name DM -port_direction OUT -port_range "\[3:0\]" -port_is_pad 1
sd_create_bus_port    -sd_name $sd_name -port_name DQ -port_direction INOUT -port_range "\[31:0\]" -port_is_pad 1
sd_create_bus_port    -sd_name $sd_name -port_name DQS -port_direction INOUT -port_range "\[3:0\]" -port_is_pad 1
sd_create_bus_port    -sd_name $sd_name -port_name DQS_N -port_direction INOUT -port_range "\[3:0\]" -port_is_pad 1
sd_create_scalar_port -sd_name $sd_name -port_name ODT -port_direction OUT -port_is_pad 1
sd_create_scalar_port -sd_name $sd_name -port_name RESET_N -port_direction OUT -port_is_pad 1

# trace pins
sd_create_scalar_port -sd_name $sd_name -port_name oTraceClk -port_direction OUT
sd_create_bus_port -sd_name $sd_name -port_name oTraceData -port_direction OUT -port_range "\[15:0\]"

# components
sd_instantiate_component -sd_name $sd_name -component_name clocks_and_resets -instance_name clocks_and_resets_0
sd_instantiate_component -sd_name $sd_name -component_name $mss_name -instance_name mss_0
sd_instantiate_component -sd_name $sd_name -component_name fic1ic -instance_name fic1ic_0
sd_instantiate_hdl_core -sd_name $sd_name -hdl_core_name axi_to_pti_wrapper -instance_name axi_to_pti_wrapper_0

# clock pin connections
source $board_path/cr/2_connect_pins.tcl
sd_connect_pins -sd_name $sd_name -pin_names {"mss_0:REFCLK" "REFCLK" }
sd_connect_pins -sd_name $sd_name -pin_names {"mss_0:REFCLK_N" "REFCLK_N" }
sd_mark_pins_unused -sd_name $sd_name -pin_names {mss_0:PLL_CPU_LOCK_M2F}
sd_mark_pins_unused -sd_name $sd_name -pin_names {mss_0:PLL_DDR_LOCK_M2F}

# mss_0 DDR connections
sd_connect_pins -sd_name $sd_name -pin_names {"DM" "mss_0:DM" }
sd_connect_pins -sd_name $sd_name -pin_names {"DQ" "mss_0:DQ" }
sd_connect_pins -sd_name $sd_name -pin_names {"DQS" "mss_0:DQS" }
sd_connect_pins -sd_name $sd_name -pin_names {"DQS_N" "mss_0:DQS_N" }
sd_connect_pins -sd_name $sd_name -pin_names {"CK" "mss_0:CK" }
sd_connect_pins -sd_name $sd_name -pin_names {"CKE" "mss_0:CKE" }
sd_connect_pins -sd_name $sd_name -pin_names {"CK_N" "mss_0:CK_N" }
sd_connect_pins -sd_name $sd_name -pin_names {"CA" "mss_0:CA" }
sd_connect_pins -sd_name $sd_name -pin_names {"CS" "mss_0:CS" }
sd_connect_pins -sd_name $sd_name -pin_names {"mss_0:ODT" "ODT" }
sd_connect_pins -sd_name $sd_name -pin_names {"mss_0:RESET_N" "RESET_N" }

# clocks_and_resets_0 connections
sd_connect_pins -sd_name $sd_name -pin_names {"clocks_and_resets_0:CLK_125MHz" "mss_0:FIC_1_ACLK" "fic1ic_0:ACLK" "axi_to_pti_wrapper_0:iClk" }
sd_connect_pins -sd_name $sd_name -pin_names {"clocks_and_resets_0:EXT_RST_N" "mss_0:MSS_RESET_N_M2F" }
sd_connect_pins -sd_name $sd_name -pin_names {"clocks_and_resets_0:FABRIC_POR_N" "mss_0:MSS_RESET_N_F2M" }
sd_connect_pins -sd_name $sd_name -pin_names {"clocks_and_resets_0:MSS_PLL_LOCKS" "mss_0:FIC_1_DLL_LOCK_M2F" }
sd_connect_pins -sd_name $sd_name -pin_names {"clocks_and_resets_0:RESETN_125MHz" "fic1ic_0:ARESETN" "axi_to_pti_wrapper_0:iRstN" }

# AXI bus connections
sd_connect_pins -sd_name $sd_name -pin_names {"mss_0:FIC_1_AXI4_INITIATOR" "fic1ic_0:AXI4mmaster0" }
sd_connect_pins -sd_name $sd_name -pin_names {"axi_to_pti_wrapper_0:axi4slave" "fic1ic_0:AXI4mslave0" }

# Trace output connections
sd_connect_pins -sd_name $sd_name -pin_names {"axi_to_pti_wrapper_0:oTraceClk" "oTraceClk" }
sd_connect_pins -sd_name $sd_name -pin_names {"axi_to_pti_wrapper_0:oTraceData" "oTraceData" }

auto_promote_pad_pins -promote_all 1
save_smartdesign -sd_name $sd_name
generate_component -component_name $sd_name
