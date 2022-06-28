# RISC-V-3D-Graphics
The code for the proejct itself is in the rtl dirrectory. There are several subfolders, but the most important are:
- src, where rtl source code is located
- test, where verilog testbench code is located
- scripts where the python scripts to generate test data,  and visualise the test output is located, this directory also has the generate_top_test_components directory which contains sim_params.csv. THis csv contains all of the simulation parameters for various tests. Many tests can be run at once using the regression.sh script.
