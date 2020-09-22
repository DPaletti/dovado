# All lines starting with #! may be eventually stripped on user preference

proc read_all_files { dir } {
    set contents [glob -directory $dir *]

    foreach item $contents {
        # recurse - go into the sub directory
        if { [file isdirectory $item] } {
            read_all_files $item
            }
        if { [file extension $item] == ".vhd" } {
            read_vhdl -library bftLib $item
        }
        if { [file extension $item] == ".v" } {
            read_verilog $item
        }
        if { [file extension $item] == ".sv" } {
            read_verilog $item
        }
    }
}

# Output Directory
set outputDir vivado_out/
file mkdir $outputDir

# Design Sources and Constraints
set src examples/vhdl_ripple_borrow_subtractor/
set xdcFile xdc/constraint.xdc
read_all_files $src
read_xdc $xdcFile

# Read box file
read_vhdl -library bftLib vhdl/box.vhd

# Run synthesis and write checkpoint
#! read_checkpoint -incremental $outputDir/post_synth.dcp ;# to be turned on for incremental runs (#! is stripped eventually)
synth_design -top box  -part xc7k70tfbv676-1 -directive default
write_checkpoint -incremental_synth -force $outputDir/post_synth.dcp ;# either -incremental_synth or nothing

# Run implementation
opt_design
#! read_checkpoint -incremental -directive Default $outputDir/post_place.dcp ;#here goes directive
place_design   ;#here goes directive

# Optimizations in case of timing violations
if {[get_property slack [get_timing_paths -max_paths 1 -nworst 1 -setup]] < 0} {
puts "found setup timing violations => running physical optimization"
phys_opt_design
}

write_checkpoint -force $outputDir/post_place.dcp

#! read_checkpoint -incremental -directive Default $outputDir/post_route.dcp ;#here goes directive
route_design   ;#here goes directive
write_checkpoint -force $outputDir/post_route.dcp

report_timing -no_header -file $outputDir/post_impl_setup_timing.rpt
report_utilization -no_primitives -omit_locs -format xml -file $outputDir/post_impl_util.xml
