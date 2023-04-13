create_clock -name {ymclk} -period 279.407655769768 [get_ports ymclk]
#create_clock -name {mclk} -period 41.6666666666667 [get_nets mclk]
create_clock -name {hsclk} -period 20.8333333333333 [get_nets hsclk]
create_generated_clock -name {mclk} -source [get_nets hsclk] -divide_by 2 [get_nets mclk]
set_clock_groups -group [get_clocks hsclk] -group [get_clocks ymclk] -asynchronous
