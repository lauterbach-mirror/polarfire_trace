set_modelsim_options \
	-use_automatic_do_file TRUE \
	-sim_runtime 35000ns \
	-tb_module_name $sd_name \
	-include_do_file TRUE \
	-included_do_file $project_dir/simulation/wave_$sd_name.do

associate_stimulus -mode new -module $sd_name
