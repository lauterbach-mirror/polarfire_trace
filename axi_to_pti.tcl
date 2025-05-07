# Import the axi_to_pti HDL+ core and its dependencies into the current
# project. After this runs succesfully, you can add the axi_to_pti core to your
# SmartDesign.

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
import_files -library work -hdl_source hdl_src/tpiu_ddr_pfio.vhd
import_files -library work -hdl_source hdl_src/tpiu_output_fifo_reader.vhd
import_files -library work -hdl_source hdl_src/axi_to_pti_impl.vhd
import_files -library work -hdl_source hdl_src/axi_to_pti.vhd
build_design_hierarchy

create_and_configure_core -core_vlnv "Actel:SgCore:PF_IO:2.0.104" -component_name PF_IO_DDR_OUT -params [list \
	"DIFFERENTIAL:false" \
	"DIRECTION:2" \
	"DYN_DELAY_LINE_EN:false" \
	"INPUT_MODE:2" \
	"LVDS_FAILSAFE_EN:false" \
	"OUTPUT_ENABLE_MODE:2" \
	"OUTPUT_MODE:2" \
]
generate_component -component_name PF_IO_DDR_OUT

create_hdl_core -file hdl/axi_to_pti.vhd -module axi_to_pti
hdl_core_add_bif -hdl_core_name axi_to_pti -bif_definition AXI4:AMBA:AMBA4:slave -bif_name axi4slave -signal_map {
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
build_design_hierarchy
