onerror {resume}
quietly WaveActivateNextPane {} 0

add wave -noupdate -expand -group AXI /trace_top_tb/trace_top_0/axi_to_pti_0/sAxiToPti/iRst
add wave -noupdate -expand -group AXI /trace_top_tb/trace_top_0/axi_to_pti_0/sAxiToPti/iClkAxi
add wave -noupdate -expand -group AXI /trace_top_tb/trace_top_0/axi_to_pti_0/sAxiToPti/iMosi
add wave -noupdate -expand -group AXI /trace_top_tb/trace_top_0/axi_to_pti_0/sAxiToPti/oMiso

add wave -noupdate -expand -group pti_data /trace_top_tb/trace_top_0/oTraceClk
add wave -noupdate -expand -group pti_data /trace_top_tb/trace_top_0/oTraceData

add wave -noupdate -expand -group formatted_data /trace_top_tb/sim_pti_rx_0/sDecode/iClkByte
add wave -noupdate -expand -group formatted_data /trace_top_tb/sim_pti_rx_0/sDecode/iInValid
add wave -noupdate -expand -group formatted_data /trace_top_tb/sim_pti_rx_0/sDecode/iInData

add wave -noupdate -expand -group decoded_data /trace_top_tb/sim_check_against_bfm_0/iClkByte
add wave -noupdate -expand -group decoded_data /trace_top_tb/sim_check_against_bfm_0/iValid
add wave -noupdate -expand -group decoded_data /trace_top_tb/sim_check_against_bfm_0/iData

add wave -noupdate /trace_top_tb/oDone

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
