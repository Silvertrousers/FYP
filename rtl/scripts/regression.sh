#!/bin/bash
# for TEST_ID in {4..15}
# do
#     echo "TEST $TEST_ID"
#     python3 scripts/test_gen.py scripts/generate_top_test_components/sim_params.csv SYNTH SIM $TEST_ID
# done

# for TEST_ID in {40..41}
# do
#     echo "TEST $TEST_ID"
#     python3 scripts/test_gen.py scripts/generate_top_test_components/sim_params.csv SYNTH SIM $TEST_ID 1
# done
for TEST_ID in {46}
do
    echo "TEST $TEST_ID"
    python3 scripts/test_gen.py scripts/generate_top_test_components/sim_params.csv SYNTH SIM $TEST_ID 1
done
# for TEST_ID in 1 2 4 8
# do
#     echo "Graphs $TEST_ID"
#     python3 scripts/visualise_rendered_pixels.py logs/log_tri_fifo_$TEST_ID.txt tri_fifo_$TEST_ID $TEST_ID
# done
