set_clock_groups -name "clk_groups" -asynchronous \
	-group [get_clocks [list "clocks_and_resets_0/PF_CCC_C0_0/PF_CCC_C0_0/pll_inst_0/OUT0"]] \
	-group [get_clocks [list "clocks_and_resets_0/PF_CCC_C0_0/PF_CCC_C0_0/pll_inst_0/OUT1"]]
