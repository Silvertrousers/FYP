iverilog -o top_test_gen -c file_list.txt -I src/hardfloat_veri/ -D MEASURE -s top_test_gen
vvp top_test_gen > run_log.txt
sed -i '1d' run_log.txt
python3 scripts/visualise_rendered_pixels.py