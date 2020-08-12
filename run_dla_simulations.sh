#!/bin/bash

PROGRAM_PATH="/home/berg/Github/MonoAlg3D_C/bin/MonoAlg3D"
INPUT_PATH="/home/berg/Github/MonoAlg3D_C/example_configs/05_Lucas/01_SRN_Purkinje/03_DLA"
SEEDS=( 152002891 1562002894 1562005513 1562005553 1562006177 1562007596 1562008172 1562008424 1562009134 1562009769 )

for SEED in "${SEEDS[@]}"; do
    #echo "${PROGRAM_PATH} -c ${INPUT_PATH}/co_min:length_seed-${SEED}_nterm:650.ini"
    ${PROGRAM_PATH} -c ${INPUT_PATH}/dla_seed-${SEED}.ini
done
