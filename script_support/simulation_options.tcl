set_modelsim_options \
	-use_automatic_do_file TRUE \
	-sim_runtime 35000ns \
	-tb_module_name $tb_sd_name \
	-include_do_file TRUE \
	-included_do_file $project_dir/simulation/wave_$tb_sd_name.do

associate_stimulus -file $project_dir/component/work/$tb_sd_name/$tb_sd_name.v -mode new -module $tb_sd_name
set_active_testbench "${tb_sd_name}::work,component/work/$tb_sd_name/$tb_sd_name.v"
