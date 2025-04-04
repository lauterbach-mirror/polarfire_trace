# Import simulation files to receive and verify PTI and Aurora trace.

# Using -hdl_source instead of -stimulous because create_hdl_core seems to
# require "HDL" sources?
import_files -library work -hdl_source sim_src/sim_axi_to_x_pkg.vhd
import_files -library work -hdl_source sim_src/sim_rcvr_align.vhd
import_files -library work -hdl_source sim_src/sim_rcvr_bond.vhd
import_files -library work -hdl_source sim_src/sim_rcvr_deserialize.vhd
import_files -library work -hdl_source sim_src/sim_tpiu_decode.vhd
import_files -library work -hdl_source sim_src/sim_pti_rx.vhd
import_files -library work -hdl_source sim_src/sim_aurora_rx.vhd
import_files -library work -hdl_source sim_src/sim_check_against_bfm.vhd
import_files -simulation sim_src/${mss_name}_PFSOC_MSS_FIC1_user.bfm
build_design_hierarchy

create_hdl_core -file hdl/sim_pti_rx.vhd -module sim_pti_rx
create_hdl_core -file hdl/sim_aurora_rx.vhd -module sim_aurora_rx
create_hdl_core -file hdl/sim_check_against_bfm.vhd -module sim_check_against_bfm
build_design_hierarchy
