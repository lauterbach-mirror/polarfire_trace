set sd_name trace_top_aurora
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

# PCIe reference clock, also used for Aurora PHYs
sd_create_scalar_port -sd_name $sd_name -port_name PCIE_REFCLK_N -port_direction IN  -port_is_pad 1
sd_create_scalar_port -sd_name $sd_name -port_name PCIE_REFCLK_P -port_direction IN  -port_is_pad 1

# FMC connector pins
sd_create_scalar_port -sd_name $sd_name -port_name FMC_DP0_TXD_N -port_direction OUT -port_is_pad 1
sd_create_scalar_port -sd_name $sd_name -port_name FMC_DP0_TXD_P -port_direction OUT -port_is_pad 1
if {$variant == "2lane"} {
	sd_create_scalar_port -sd_name $sd_name -port_name FMC_DP1_TXD_N -port_direction OUT -port_is_pad 1
	sd_create_scalar_port -sd_name $sd_name -port_name FMC_DP1_TXD_P -port_direction OUT -port_is_pad 1
}

# components
sd_instantiate_component -sd_name $sd_name -component_name clocks_and_resets -instance_name clocks_and_resets_0
sd_instantiate_component -sd_name $sd_name -component_name $mss_name -instance_name mss_0
sd_instantiate_component -sd_name $sd_name -component_name fic1ic -instance_name fic1ic_0
sd_instantiate_component -sd_name $sd_name -component_name aurora_ref  -instance_name aurora_ref_0
sd_instantiate_component -sd_name $sd_name -component_name aurora_pll  -instance_name aurora_pll_0
sd_instantiate_component -sd_name $sd_name -component_name aurora_xcvr_$variant -instance_name aurora_xcvr_0

sd_instantiate_hdl_core -sd_name $sd_name -hdl_core_name axi_to_aurora_$variant -instance_name axi_to_aurora_0
sd_configure_core_instance -sd_name $sd_name -instance_name axi_to_aurora_0
sd_save_core_instance_config -sd_name $sd_name -instance_name axi_to_aurora_0

# clock pin connections
source $board_path/cr/2_connect_pins.tcl
sd_connect_pins -sd_name $sd_name -pin_names [list "mss_0:REFCLK" "REFCLK"]
sd_connect_pins -sd_name $sd_name -pin_names [list "mss_0:REFCLK_N" "REFCLK_N"]
sd_mark_pins_unused -sd_name $sd_name -pin_names "mss_0:PLL_CPU_LOCK_M2F"
sd_mark_pins_unused -sd_name $sd_name -pin_names "mss_0:PLL_DDR_LOCK_M2F"

# mss_0 DDR connections
sd_connect_pins -sd_name $sd_name -pin_names [list "DM" "mss_0:DM"]
sd_connect_pins -sd_name $sd_name -pin_names [list "DQ" "mss_0:DQ"]
sd_connect_pins -sd_name $sd_name -pin_names [list "DQS" "mss_0:DQS"]
sd_connect_pins -sd_name $sd_name -pin_names [list "DQS_N" "mss_0:DQS_N"]
sd_connect_pins -sd_name $sd_name -pin_names [list "CK" "mss_0:CK"]
sd_connect_pins -sd_name $sd_name -pin_names [list "CKE" "mss_0:CKE"]
sd_connect_pins -sd_name $sd_name -pin_names [list "CK_N" "mss_0:CK_N"]
sd_connect_pins -sd_name $sd_name -pin_names [list "CA" "mss_0:CA"]
sd_connect_pins -sd_name $sd_name -pin_names [list "CS" "mss_0:CS"]
sd_connect_pins -sd_name $sd_name -pin_names [list "mss_0:ODT" "ODT"]
sd_connect_pins -sd_name $sd_name -pin_names [list "mss_0:RESET_N" "RESET_N"]

# clocks_and_resets_0 connections
sd_connect_pins -sd_name $sd_name -pin_names [list "clocks_and_resets_0:CLK_125MHz" "mss_0:FIC_1_ACLK" "fic1ic_0:ACLK" "axi_to_aurora_0:iClkAxi"]
sd_connect_pins -sd_name $sd_name -pin_names [list "clocks_and_resets_0:EXT_RST_N" "mss_0:MSS_RESET_N_M2F"]
sd_connect_pins -sd_name $sd_name -pin_names [list "clocks_and_resets_0:FABRIC_POR_N" "mss_0:MSS_RESET_N_F2M"]
sd_connect_pins -sd_name $sd_name -pin_names [list "clocks_and_resets_0:MSS_PLL_LOCKS" "mss_0:FIC_1_DLL_LOCK_M2F"]
sd_connect_pins -sd_name $sd_name -pin_names [list "clocks_and_resets_0:RESETN_125MHz" "fic1ic_0:ARESETN" "axi_to_aurora_0:iRstN"]

# transceiver connections
sd_connect_pins -sd_name $sd_name -pin_names [list "PCIE_REFCLK_N" "aurora_ref_0:REF_CLK_PAD_N"]
sd_connect_pins -sd_name $sd_name -pin_names [list "PCIE_REFCLK_P" "aurora_ref_0:REF_CLK_PAD_P"]
sd_connect_pins -sd_name $sd_name -pin_names [list "aurora_pll_0:REF_CLK" "aurora_ref_0:REF_CLK"]
sd_connect_pins -sd_name $sd_name -pin_names [list "aurora_pll_0:CLKS_TO_XCVR" "aurora_xcvr_0:CLKS_FROM_TXPLL_0"]
sd_connect_pins -sd_name $sd_name -pin_names [list "aurora_pll_0:PLL_LOCK" "axi_to_aurora_0:PLL_LOCK"]

# AXI bus connections
sd_connect_pins -sd_name $sd_name -pin_names [list "mss_0:FIC_1_AXI4_INITIATOR" "fic1ic_0:AXI4mmaster0"]
sd_connect_pins -sd_name $sd_name -pin_names [list "axi_to_aurora_0:axi4slave" "fic1ic_0:AXI4mslave0"]

if {$variant == "2lane"} {
	set lanes [list "0" "1"]
} else {
	set lanes [list "0"]
}
foreach lane $lanes {
	# Trace output connections
	foreach port [list "TX_CLK_R" "TX_CLK_STABLE" "PCS_ARST_N" "TX_DISPFNC" "8B10B_TX_K" "TX_DATA" "PMA_ARST_N"] {
		sd_connect_pins -sd_name $sd_name -pin_names [list "axi_to_aurora_0:LANE${lane}_$port" "aurora_xcvr_0:LANE${lane}_$port"]
	}

	# Transeiver output connections
	sd_connect_pins -sd_name $sd_name -pin_names [list "FMC_DP${lane}_TXD_N" "aurora_xcvr_0:LANE${lane}_TXD_N"]
	sd_connect_pins -sd_name $sd_name -pin_names [list "FMC_DP${lane}_TXD_P" "aurora_xcvr_0:LANE${lane}_TXD_P"]
}

auto_promote_pad_pins -promote_all 1
save_smartdesign -sd_name $sd_name
generate_component -component_name $sd_name
