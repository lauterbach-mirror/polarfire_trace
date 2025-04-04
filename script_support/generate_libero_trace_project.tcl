# sourced by scripts in parent directory; do not execute directly!

if {![info exists project_name]} {
	error "Do not execute this project directly!"
}

if { [lindex $tcl_platform(os) 0]  == "Windows" } {
	if {[string length [pwd]] < 90} {
		puts "Project path length ok."
	} else {
		error "Path to project is too long, please use a better operating system and try again."
	}
}

set install_loc [defvar_get -name ACTEL_SW_DIR]
set mss_config_loc "$install_loc/bin64/pfsoc_mss"
set local_dir [pwd]
set src_path ./script_support
set constraint_path ./script_support/constraints/H264
set project_dir "./$project_name"

file delete -force $project_dir

new_project \
	-location $project_dir \
	-name $project_name \
	-project_description {} \
	-block_mode 0 \
	-standalone_peripheral_initialization 0 \
	-instantiate_in_smartdesign 1 \
	-ondemand_build_dh 1 \
	-use_relative_path 0 \
	-linked_files_root_dir_env {} \
	-hdl {VERILOG} \
	-family {PolarFireSoC} \
	-die $project_die \
	-package $project_package \
	-speed $project_speed \
	-die_voltage $project_die_voltage \
	-part_range $project_part_range \
	-adv_options "IO_DEFT_STD:LVCMOS 1.8V" \
	-adv_options "RESTRICTPROBEPINS:1" \
	-adv_options "RESTRICTSPIPINS:0" \
	-adv_options "SYSTEM_CONTROLLER_SUSPEND_MODE:0" \
	-adv_options "TEMPR:$project_part_range" \
	-adv_options "VCCI_1.2_VOLTR:$project_part_range" \
	-adv_options "VCCI_1.5_VOLTR:$project_part_range" \
	-adv_options "VCCI_1.8_VOLTR:$project_part_range" \
	-adv_options "VCCI_2.5_VOLTR:$project_part_range" \
	-adv_options "VCCI_3.3_VOLTR:$project_part_range" \
	-adv_options "VOLTR:$project_part_range"

download_core -vlnv {Actel:DirectCore:COREAXI4INTERCONNECT:2.8.103} -location {www.microchip-ip.com/repositories/DirectCore}
download_core -vlnv {Actel:DirectCore:CORERESET_PF:2.3.100} -location {www.microchip-ip.com/repositories/DirectCore}
download_core -vlnv {Actel:SgCore:PF_CCC:2.2.220} -location {www.microchip-ip.com/repositories/SgCore}
download_core -vlnv {Actel:SgCore:PF_CLK_DIV:1.0.103} -location {www.microchip-ip.com/repositories/SgCore}
download_core -vlnv {Actel:SgCore:PF_OSC:1.0.102} -location {www.microchip-ip.com/repositories/SgCore}
download_core -vlnv {Actel:SgCore:PF_XCVR_REF_CLK:1.0.103} -location {www.microchip-ip.com/repositories/SgCore}
download_core -vlnv {Actel:SgCore:PF_IO:2.0.104} -location {www.microchip-ip.com/repositories/SgCore}
download_core -vlnv {Microsemi:SgCore:PFSOC_INIT_MONITOR:1.0.307} -location {www.microchip-ip.com/repositories/SgCore}

file mkdir $project_dir/mss
exec $mss_config_loc -GENERATE -CONFIGURATION_FILE:$board_path/$mss_name.cfg -OUTPUT_DIR:$project_dir/mss
import_mss_component -file $project_dir/mss/$mss_name.cxz

source axi_to_pti.tcl
source $src_path/add_simulation_files.tcl

source $board_path/cr/0_create_components.tcl

source $src_path/fic1ic.tcl
source $src_path/trace_top.tcl
source $src_path/trace_top_tb.tcl

build_design_hierarchy
set_root -module trace_top::work
derive_constraints_sdc

import_files \
	-convert_EDN_to_HDL 0 \
	-io_pdc $board_path/$constr_trace \
	-io_pdc $board_path/pins.pdc \
	-fp_pdc $board_path/floorplan.pdc \
	-sdc "$src_path/timing.sdc"

organize_tool_files -tool SYNTHESIZE \
	-file "$project_dir/constraint/trace_top_derived_constraints.sdc" \
	-module {trace_top::work} \
	-input_type {constraint}

organize_tool_files -tool PLACEROUTE \
	-file "$project_dir/constraint/trace_top_derived_constraints.sdc" \
	-file "$project_dir/constraint/fp/floorplan.pdc" \
	-file "$project_dir/constraint/io/pins.pdc" \
	-file "$project_dir/constraint/io/$constr_trace" \
	-file "$project_dir/constraint/timing.sdc" \
	-module {trace_top::work} \
	-input_type {constraint}
set_as_target -type io_pdc -file $constr_trace

save_project
