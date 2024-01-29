# Script to automatically package the projects IP
# To run: vivado -mode tcl -source pkg_ip.tcl -notrace

set projName   "axis-video-frame-cleaner"
set partID     "xczu3eg-sfvc784-1-e"
set currentDir [file normalize .]
set ipGenDir   [file join $currentDir "ip_tmp"]
set ipDir      [file join $currentDir "ip_repo" $projName]
set corePath   [file join $ipDir component.xml]
set vendor     "midimaster21b"
set library    "imaging"
set taxonomy   "/Imaging"
set files      [get_files];
set topModule  frame_cleaner

if { [info exists ::env(FUSESOC_FPGA_PART_ID) ] } {
    set partID ::env(FUSESOC_FPGA_PART_ID)
}

puts "================================================================";
puts "Creating project \"$projName\" \[$partID\]";
puts "================================================================";
puts "Working directory: $currentDir";
puts "Project directory: $ipGenDir";
puts "IP repo directory: $ipDir";

create_project -force $projName $ipGenDir -part $partID
set_property target_language VHDL [current_project]
add_files -norecurse $files
set_property top $topModule [current_fileset]
update_compile_order -fileset sources_1

puts "================================================================";
puts "Beginning IPX stuffs";
puts "================================================================";
ipx::package_project -root_dir $ipDir -vendor $vendor -library $library -taxonomy $taxonomy -import_files -set_current false
ipx::unload_core $corePath
ipx::edit_ip_in_project -upgrade true -name tmp_edit_project -directory $ipDir $corePath
update_compile_order -fileset sources_1
set curr_core [ipx::current_core];
set vlnv [get_property vlnv $curr_core];
puts "$projName core: $vlnv";
set_property core_revision 1 [ipx::current_core]
# ipx::add_bus_parameter FREQ_HZ [ipx::get_bus_interfaces s_axi_ctrl -of_objects [ipx::current_core]]
# ipx::add_bus_parameter FREQ_HZ [ipx::get_bus_interfaces s_axis_video_0 -of_objects [ipx::current_core]]
# ipx::add_bus_parameter FREQ_HZ [ipx::get_bus_interfaces s_axis_video_1 -of_objects [ipx::current_core]]
# ipx::add_bus_parameter FREQ_HZ [ipx::get_bus_interfaces m_axis_video_0 -of_objects [ipx::current_core]]
# ipx::add_bus_parameter FREQ_HZ [ipx::get_bus_interfaces m_axis_video_1 -of_objects [ipx::current_core]]
# ipx::add_bus_parameter FREQ_HZ [ipx::get_bus_interfaces m_axis_video_mux -of_objects [ipx::current_core]]
ipx::update_source_project_archive -component [ipx::current_core]
ipx::create_xgui_files [ipx::current_core]
ipx::update_checksums [ipx::current_core]
ipx::check_integrity [ipx::current_core]
ipx::save_core [ipx::current_core]
ipx::move_temp_component_back -component [ipx::current_core]
close_project -delete
set_property  ip_repo_paths  $ipDir [current_project]
update_ip_catalog

puts "================================================================";
puts "Finished Creating project \"$projName\" \[$partID\]";
puts "================================================================";

