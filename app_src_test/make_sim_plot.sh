make && xsim bin/app_src_test.xe > dump.txt && gnuplot -p -e  'plot "dump.txt" with lines'
