#!/bin/bash
set -e

RUN_VERI=false
RUN_SPIKE=false

# If no args are given → run both
if [ $# -eq 0 ]; then
  RUN_VERI=true
  RUN_SPIKE=true
else
  for arg in "$@"; do
    case "$arg" in
      veri)
        RUN_VERI=true
        ;;
      spike)
        RUN_SPIKE=true
        ;;
      *)
        echo "Unknown argument: '$arg'"
        echo "Usage: source run_regression.sh [veri|spike]"
        return 1
        ;;
    esac
  done
fi

export RISCV=/home/valerio/riscv
export TRACE_FAST=0
export NUM_JOBS=3

OUT_DIR="out_$(date +%Y-%m-%d)"

source setup-env.sh

# Create output directory
mkdir -p out

# ================================================================
# 0. Compile mptw_test for Verilator  (only if RUN_VERI == true)
# ================================================================
if [ "$RUN_VERI" = true ]; then
  RISCV_GCC=/home/valerio/riscv/bin/riscv-none-elf-gcc
  LINKER=../../config/gen_from_riscv_config/linker/link.ld
  OUT=out/mptw_test.elf

  $RISCV_GCC \
    ../tests/custom/mptw_test/s_function.S \
    ../tests/custom/common/syscalls.c \
    ../tests/custom/common/crt.S \
    ../tests/custom/mptw_test/mptw_test.c \
    ../regress/verif/tests/riscv-arch-test/riscv-test-suite/rv64i_m/I/src/add-01.S \
    -I../tests/custom/env \
    -I../tests/custom/common \
    -I../regress/verif/tests/riscv-arch-test/riscv-test-suite/env/ \
    -I../core-v-verif/vendor/riscv/riscv-isa-sim/arch_test_target/spike/ \
    -DXLEN=64 -DTEST_CASE_1=True \
    -T$LINKER \
    -static -mcmodel=medany -fvisibility=hidden -nostdlib -nostartfiles -D__NO_TOHOST -lgcc \
    -march=rv64gch_zba_zbb_zbs_zbc -mabi=lp64d \
    -o $OUT
    
  mv out/mptw_test.elf out/mptw_test.o
  riscv32-unknown-elf-objdump -d out/mptw_test.o > out/mptw_test_verilator.disasm

  # 1. Run Verilator Simulation
  python3 cva6.py \
    --target cv64a6_imafdch_sv39 \
    --iss=veri-testharness \
    --iss_yaml=cva6.yaml \
    --elf_tests=out/mptw_test.o \
    --linker=../../config/gen_from_riscv_config/linker/link.ld \
    --steps=iss_sim


  # 1.1 Convert Verilator .log file into .csv file
  cd ../../
  PYTHONPATH=verif/sim/dv/scripts python3 verif/sim/verilator_log_to_trace_csv.py \
    --log verif/sim/${OUT_DIR}/veri-testharness_sim/mptw_test.cv64a6_imafdch_sv39.log \
    --csv verif/sim/${OUT_DIR}/veri-testharness_sim/mptw_test.cv64a6_imafdch_sv39.csv
    
  cd verif/sim
fi

# ================================================================
# 2. Compile mptw_test for Spike  (only if RUN_SPIKE == true)
# ================================================================
if [ "$RUN_SPIKE" = true ]; then
  $RISCV_GCC \
    ../tests/custom/mptw_test/s_function.S \
    ../tests/custom/common/syscalls.c \
    ../tests/custom/common/crt.S \
    ../tests/custom/mptw_test/mptw_test.c \
    ../regress/verif/tests/riscv-arch-test/riscv-test-suite/rv64i_m/I/src/add-01.S \
    -I../tests/custom/env \
    -I../tests/custom/common \
    -I../regress/verif/tests/riscv-arch-test/riscv-test-suite/env/ \
    -I../core-v-verif/vendor/riscv/riscv-isa-sim/arch_test_target/spike/ \
    -DXLEN=64 -DTEST_CASE_1=True \
    -T$LINKER \
    -static -mcmodel=medany -fvisibility=hidden -D SPIKE -nostdlib -nostartfiles -D__NO_TOHOST -lgcc \
    -march=rv64gch_zba_zbb_zbs_zbc -mabi=lp64d \
    -o $OUT
    
  mv out/mptw_test.elf out/mptw_test.o
  riscv32-unknown-elf-objdump -d out/mptw_test.o > out/mptw_test_spike.disasm


  # 3. Run Spike simulation
  python3 cva6.py \
    --target cv64a6_imafdch_sv39 \
    --iss=spike \
    --iss_yaml=cva6.yaml \
    --elf_tests=out/mptw_test.o \
    --linker=../../config/gen_from_riscv_config/linker/link.ld \
    --steps=iss_sim

  cd ../../

  # 3.1 Convert Spike .log file into .csv file
  PYTHONPATH=verif/sim/dv/scripts python3 verif/sim/cva6_spike_log_to_trace_csv.py   \
    --log verif/sim/${OUT_DIR}/spike_sim/mptw_test.cv64a6_imafdch_sv39.log   \
    --csv verif/sim/${OUT_DIR}/spike_sim/mptw_test.cv64a6_imafdch_sv39.csv


  # 4. Final compare. Must have both .csv file ready
  cd verif/sim
fi

# ================================================================
# 4. Final compare (only if both were executed)
# ================================================================
if [ "$RUN_VERI" = true ] && [ "$RUN_SPIKE" = true ]; then
  PYTHONPATH=dv/scripts python3 compare_csv_only.py
fi
