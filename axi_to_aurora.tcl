# Import the axi_to_aurora HDL+ cores and their dependencies into the current
# project. After this runs succesfully, you can add the axi_to_aurora_1lane or
# axi_to_aurora_2lane core to your SmartDesign.

import_files -library work -hdl_source hdl_src/util_pkg.vhd
import_files -library work -hdl_source hdl_src/graycnt_pkg.vhd
import_files -library work -hdl_source hdl_src/FifoScReg.vhd
import_files -library work -hdl_source hdl_src/FifoDcReg.vhd
import_files -library work -hdl_source hdl_src/axi4_fic1_from_mss_pkg.vhd
import_files -library work -hdl_source hdl_src/axi4_fic1_from_mss_to_stream.vhd
import_files -library work -hdl_source hdl_src/tpiu_packer_pkg.vhd
import_files -library work -hdl_source hdl_src/tpiu_packer_control.vhd
import_files -library work -hdl_source hdl_src/tpiu_packer_data.vhd
import_files -library work -hdl_source hdl_src/tpiu_packer_output.vhd
import_files -library work -hdl_source hdl_src/tpiu_packer_scheduler.vhd
import_files -library work -hdl_source hdl_src/tpiu_packer.vhd
import_files -library work -hdl_source hdl_src/smb_compress.vhd
import_files -library work -hdl_source hdl_src/smb_sync.vhd
import_files -library work -hdl_source hdl_src/lfsr_65_1034.vhd
import_files -library work -hdl_source hdl_src/aurora_idle_generator.vhd
import_files -library work -hdl_source hdl_src/aurora_frame.vhd
import_files -library work -hdl_source hdl_src/aurora_encoder.vhd
import_files -library work -hdl_source hdl_src/aurora_resets.vhd
import_files -library work -hdl_source hdl_src/axi_to_aurora_impl.vhd
import_files -library work -hdl_source hdl_src/axi_to_aurora_1lane.vhd
import_files -library work -hdl_source hdl_src/axi_to_aurora_2lane.vhd
build_design_hierarchy

foreach lanes [list "1lane" "2lane"] {
	create_hdl_core -file hdl/axi_to_aurora_$lanes.vhd -module axi_to_aurora_$lanes
	hdl_core_add_bif -hdl_core_name axi_to_aurora_$lanes -bif_definition AXI4:AMBA:AMBA4:slave -bif_name axi4slave -signal_map {
		"AWID:AWID"
		"AWADDR:AWADDR"
		"AWLEN:AWLEN"
		"AWSIZE:AWSIZE"
		"AWBURST:AWBURST"
		"AWVALID:AWVALID"
		"AWREADY:AWREADY"
		"WDATA:WDATA"
		"WSTRB:WSTRB"
		"WLAST:WLAST"
		"WVALID:WVALID"
		"WREADY:WREADY"
		"BID:BID"
		"BRESP:BRESP"
		"BVALID:BVALID"
		"BREADY:BREADY"
		"ARID:ARID"
		"ARADDR:ARADDR"
		"ARLEN:ARLEN"
		"ARSIZE:ARSIZE"
		"ARBURST:ARBURST"
		"ARVALID:ARVALID"
		"ARREADY:ARREADY"
		"RID:RID"
		"RDATA:RDATA"
		"RRESP:RRESP"
		"RLAST:RLAST"
		"RVALID:RVALID"
		"RREADY:RREADY"
	}
}
build_design_hierarchy
