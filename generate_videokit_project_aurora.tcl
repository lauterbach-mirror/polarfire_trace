if {[llength $argv] >= 1} {
	set variant [lindex $argv 0]
} else {
	set variant "1lane"
}


set src_path            ./script_support
set board_path          $src_path/videokit

set project_name        "trace_videokit_$variant"
set project_die         MPFS250TS
set project_package     FCG1152
set project_speed       -1
set project_die_voltage 1.0
set project_part_range  IND

set constr_trace        io_videokit_fmc_aurora_$variant.pdc

set mss_name            mss_videokit_trace

source $src_path/generate_libero_trace_project_aurora.tcl
