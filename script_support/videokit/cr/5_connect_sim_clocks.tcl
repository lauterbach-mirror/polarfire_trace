sd_invert_pins -sd_name $sd_name -pin_names {trace_top_0:REFCLK_N}
sd_invert_pins -sd_name $sd_name -pin_names {trace_top_0:REF_CLK_PAD_N}
sd_connect_pins -sd_name $sd_name -pin_names {"clk_gen_refclk_0:CLK" "trace_top_0:REFCLK" "trace_top_0:REFCLK_N"}
sd_connect_pins -sd_name $sd_name -pin_names {"clk_gen_ref_clk_pad_0:CLK" "trace_top_0:REF_CLK_PAD_N" "trace_top_0:REF_CLK_PAD_P"}
