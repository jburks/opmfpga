create_clock -name {ymclk} -period 279.407655769768 [get_ports ymclk]
create_clock -name {mclk} -period 41.6666666666667 [get_nets mclk]
set_clock_groups -group [get_clocks mclk] -group [get_clocks ymclk] -asynchronous
