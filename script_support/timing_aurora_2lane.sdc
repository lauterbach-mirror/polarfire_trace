set_clock_groups -name "clk_groups" -asynchronous \
	-group [get_clocks [list "PCIE_REFCLK_P"]] \
	-group [get_clocks [list "aurora_xcvr_0/I_XCVR/LANE0/TX_CLK_R"]] \
	-group [get_clocks [list "aurora_xcvr_0/I_XCVR/LANE1/TX_CLK_R"]] \
	-group [get_clocks [list "REF_CLK_PAD_P" "clocks_and_resets_0/PF_CCC_C0_0/PF_CCC_C0_0/pll_inst_0/OUT0"]]
