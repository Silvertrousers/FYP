#!/bin/bash
# for TEST_ID in {4..15}
# do
#     echo "TEST $TEST_ID"
#     python3 scripts/test_gen.py scripts/generate_top_test_components/sim_params.csv SYNTH SIM $TEST_ID
# done

for TEST_ID in {17..26}
do
    echo "TEST $TEST_ID"
    python3 scripts/test_gen.py scripts/generate_top_test_components/sim_params.csv SYNTH SIM $TEST_ID
done