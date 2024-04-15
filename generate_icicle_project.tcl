set src_path            ./script_support
set board_path          $src_path/icicle

set project_name        trace_icicle
set project_die         MPFS250T_ES
set project_package     FCVG484
set project_speed       STD
set project_die_voltage 1.05
set project_part_range  EXT

set constr_trace        io_icicle_rpi.pdc

set mss_name            mss_icicle_trace

source $src_path/generate_libero_trace_project.tcl
