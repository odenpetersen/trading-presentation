add_wave_divider {Clock}
add_wave /tb/clk
add_wave_divider {In-order}
add_wave -radix unsigned /tb/i_pc
add_wave /tb/stall
add_wave -radix unsigned /tb/i_ret
add_wave -radix unsigned /tb/i_cycles
add_wave /tb/i_done
add_wave_divider {Tomasulo}
add_wave -radix unsigned /tb/t_pc
add_wave -radix bin /tb/rs_busy
add_wave /tb/cdb_v
add_wave -radix unsigned /tb/cdb_tag
add_wave -radix unsigned /tb/cdb_val
add_wave -radix unsigned /tb/t_ret
add_wave -radix unsigned /tb/t_cycles
add_wave /tb/t_done
set r [get_waves -r /tb/i_ret /tb/t_ret]
foreach o $r {set_property display_type analog $o;set_property analog_format cityscape $o;set_property height 60 $o}
run all
save_wave_config tomasulo.wcfg
exit
