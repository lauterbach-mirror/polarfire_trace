onerror {resume}
quietly WaveActivateNextPane {} 0

add wave -noupdate -expand -group AXI /trace_top_aurora_tb/trace_top_aurora_0/axi_to_aurora_0/sAxiToHsstp/iRst
add wave -noupdate -expand -group AXI /trace_top_aurora_tb/trace_top_aurora_0/axi_to_aurora_0/sAxiToHsstp/iClkAxi
add wave -noupdate -expand -group AXI /trace_top_aurora_tb/trace_top_aurora_0/axi_to_aurora_0/sAxiToHsstp/iMosi
add wave -noupdate -expand -group AXI /trace_top_aurora_tb/trace_top_aurora_0/axi_to_aurora_0/sAxiToHsstp/oMiso

add wave -noupdate -group tx_lane0 /trace_top_aurora_tb/trace_top_aurora_0/axi_to_aurora_0/LANE0_PCS_ARST_N
add wave -noupdate -group tx_lane0 /trace_top_aurora_tb/trace_top_aurora_0/axi_to_aurora_0/LANE0_PMA_ARST_N
add wave -noupdate -group tx_lane0 /trace_top_aurora_tb/trace_top_aurora_0/axi_to_aurora_0/LANE0_TX_CLK_STABLE
add wave -noupdate -group tx_lane0 /trace_top_aurora_tb/trace_top_aurora_0/axi_to_aurora_0/LANE0_TX_CLK_R
add wave -noupdate -group tx_lane0 /trace_top_aurora_tb/trace_top_aurora_0/axi_to_aurora_0/LANE0_TX_DATA
add wave -noupdate -group tx_lane0 /trace_top_aurora_tb/trace_top_aurora_0/axi_to_aurora_0/LANE0_8B10B_TX_K
add wave -noupdate -group tx_lane0 /trace_top_aurora_tb/trace_top_aurora_0/axi_to_aurora_0/LANE0_TX_DISPFNC

add wave -noupdate -group tx_lane1 /trace_top_aurora_tb/trace_top_aurora_0/axi_to_aurora_0/LANE1_PCS_ARST_N
add wave -noupdate -group tx_lane1 /trace_top_aurora_tb/trace_top_aurora_0/axi_to_aurora_0/LANE1_PMA_ARST_N
add wave -noupdate -group tx_lane1 /trace_top_aurora_tb/trace_top_aurora_0/axi_to_aurora_0/LANE1_TX_CLK_STABLE
add wave -noupdate -group tx_lane1 /trace_top_aurora_tb/trace_top_aurora_0/axi_to_aurora_0/LANE1_TX_CLK_R
add wave -noupdate -group tx_lane1 /trace_top_aurora_tb/trace_top_aurora_0/axi_to_aurora_0/LANE1_TX_DATA
add wave -noupdate -group tx_lane1 /trace_top_aurora_tb/trace_top_aurora_0/axi_to_aurora_0/LANE1_8B10B_TX_K
add wave -noupdate -group tx_lane1 /trace_top_aurora_tb/trace_top_aurora_0/axi_to_aurora_0/LANE1_TX_DISPFNC

add wave -noupdate -expand -group serial_data /trace_top_aurora_tb/trace_top_aurora_0/FMC_DP0_TXD_N
add wave -noupdate -expand -group serial_data /trace_top_aurora_tb/trace_top_aurora_0/FMC_DP0_TXD_P
add wave -noupdate -expand -group serial_data /trace_top_aurora_tb/trace_top_aurora_0/FMC_DP1_TXD_N
add wave -noupdate -expand -group serial_data /trace_top_aurora_tb/trace_top_aurora_0/FMC_DP1_TXD_P

add wave -noupdate -group rx_lane0 /trace_top_aurora_tb/aurora_dummy_xcvr_0/LANE0_PCS_ARST_N
add wave -noupdate -group rx_lane0 /trace_top_aurora_tb/aurora_dummy_xcvr_0/LANE0_PMA_ARST_N
add wave -noupdate -group rx_lane0 /trace_top_aurora_tb/aurora_dummy_xcvr_0/LANE0_8B10B_RX_K
add wave -noupdate -group rx_lane0 /trace_top_aurora_tb/aurora_dummy_xcvr_0/LANE0_RX_CLK_R
add wave -noupdate -group rx_lane0 /trace_top_aurora_tb/aurora_dummy_xcvr_0/LANE0_RX_CODE_VIOLATION
add wave -noupdate -group rx_lane0 /trace_top_aurora_tb/aurora_dummy_xcvr_0/LANE0_RX_DATA
add wave -noupdate -group rx_lane0 /trace_top_aurora_tb/aurora_dummy_xcvr_0/LANE0_RX_DISPARITY_ERROR
add wave -noupdate -group rx_lane0 /trace_top_aurora_tb/aurora_dummy_xcvr_0/LANE0_RX_READY
add wave -noupdate -group rx_lane0 /trace_top_aurora_tb/aurora_dummy_xcvr_0/LANE0_RX_VAL

add wave -noupdate -group rx_lane1 /trace_top_aurora_tb/aurora_dummy_xcvr_0/LANE1_PCS_ARST_N
add wave -noupdate -group rx_lane1 /trace_top_aurora_tb/aurora_dummy_xcvr_0/LANE1_PMA_ARST_N
add wave -noupdate -group rx_lane1 /trace_top_aurora_tb/aurora_dummy_xcvr_0/LANE1_8B10B_RX_K
add wave -noupdate -group rx_lane1 /trace_top_aurora_tb/aurora_dummy_xcvr_0/LANE1_RX_CLK_R
add wave -noupdate -group rx_lane1 /trace_top_aurora_tb/aurora_dummy_xcvr_0/LANE1_RX_CODE_VIOLATION
add wave -noupdate -group rx_lane1 /trace_top_aurora_tb/aurora_dummy_xcvr_0/LANE1_RX_DATA
add wave -noupdate -group rx_lane1 /trace_top_aurora_tb/aurora_dummy_xcvr_0/LANE1_RX_DISPARITY_ERROR
add wave -noupdate -group rx_lane1 /trace_top_aurora_tb/aurora_dummy_xcvr_0/LANE1_RX_READY
add wave -noupdate -group rx_lane1 /trace_top_aurora_tb/aurora_dummy_xcvr_0/LANE1_RX_VAL

add wave -noupdate -expand -group formatted_data /trace_top_aurora_tb/sim_aurora_rx_0/sDecode/iClkByte
add wave -noupdate -expand -group formatted_data /trace_top_aurora_tb/sim_aurora_rx_0/sDecode/iInValid
add wave -noupdate -expand -group formatted_data /trace_top_aurora_tb/sim_aurora_rx_0/sDecode/iInData

add wave -noupdate -expand -group decoded_data /trace_top_aurora_tb/sim_check_against_bfm_0/iClkByte
add wave -noupdate -expand -group decoded_data /trace_top_aurora_tb/sim_check_against_bfm_0/iValid
add wave -noupdate -expand -group decoded_data /trace_top_aurora_tb/sim_check_against_bfm_0/iData

add wave -noupdate /trace_top_aurora_tb/oDone

TreeUpdate [SetDefaultTree]
WaveRestoreCursors {{Cursor 1} {0 ps} 0}
quietly wave cursor active 1
configure wave -namecolwidth 300
configure wave -valuecolwidth 100
configure wave -justifyvalue left
configure wave -signalnamewidth 1
configure wave -snapdistance 10
configure wave -datasetprefix 0
configure wave -rowmargin 4
configure wave -childrowmargin 2
configure wave -gridoffset 0
configure wave -gridperiod 1
configure wave -griddelta 40
configure wave -timeline 0
configure wave -timelineunits ps
update
WaveRestoreZoom {0 ps} {35000000 ps}
