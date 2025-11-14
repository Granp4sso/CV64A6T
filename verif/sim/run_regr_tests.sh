#!/bin/bash

RUN_VERI=false
RUN_SPIKE=false

# ================================================================
# 0. Check required argument (assembly file)
# ================================================================
if [ $# -lt 1 ]; then
  echo "Usage: source run_regression.sh [veri|spike|both] <asm_file.S>"
  return 1
fi

# Extract last argument as ASM file (must end with .S)
ASM_FILE="${@: -1}"

if [[ "$ASM_FILE" != *.S ]]; then
  echo "Error: last argument must be an assembly file (.S)"
  return 1
fi

# Remove last argument from list (so only flags remain)
set -- "${@:1:$(($#-1))}"

# ================================================================
# 1. Parse optional arguments (veri / spike)
# ================================================================
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
      both)
        RUN_VERI=true
        RUN_SPIKE=true
        ;;
      *)
        echo "Unknown argument: '$arg'"
        echo "Usage: source run_regression.sh [veri|spike|both] <asm_file.S>"
        return 1
        ;;
    esac
  done
fi

# ================================================================
# 2. Environment setup
# ================================================================
export RISCV=/home/valerio/riscv
export TRACE_FAST=1
export NUM_JOBS=3

OUT_DIR="out_$(date +%Y-%m-%d)"

source setup-env.sh

# Create output directory
rm -rf out && mkdir -p out

# Delete old files safely (no error if missing)
rm -f ${OUT_DIR}/veri-testharness_sim/mptw_test.cv64a6_imafdch_sv39.{log,csv,vcd}
rm -f ${OUT_DIR}/spike_sim/mptw_test.cv64a6_imafdch_sv39.{log,csv}

# ================================================================
# 3. Common variables
# ================================================================
RISCV_GCC=/home/valerio/riscv/bin/riscv-none-elf-gcc
LINKER=../../config/gen_from_riscv_config/linker/link.ld
OUT=out/mptw_test.elf

# ================================================================
# 4. Compile for Verilator
# ================================================================
if [ "$RUN_VERI" = true ]; then
  echo ">>> Compiling for Verilator with ASM file: $ASM_FILE"

  $RISCV_GCC \
    ../tests/custom/mptw_test/s_function.S \
    ../tests/custom/common/syscalls.c \
    ../tests/custom/common/crt.S \
    ../tests/custom/mptw_test/mptw_test.c \
    ../regress/verif/tests/riscv-arch-test/riscv-test-suite/rv64i_m/I/src/"$ASM_FILE" \
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

  # Run Verilator simulation
  python3 cva6.py \
    --target cv64a6_imafdch_sv39 \
    --iss=veri-testharness \
    --iss_yaml=cva6.yaml \
    --elf_tests=out/mptw_test.o \
    --linker=$LINKER \
    --steps=iss_sim

  cd ../../

  # Convert log to CSV
  LOG_FILE=verif/sim/${OUT_DIR}/veri-testharness_sim/mptw_test.cv64a6_imafdch_sv39.log
  CSV_FILE=verif/sim/${OUT_DIR}/veri-testharness_sim/mptw_test.cv64a6_imafdch_sv39.csv

  if [ -f "$LOG_FILE" ]; then  
    PYTHONPATH=verif/sim/dv/scripts python3 verif/sim/verilator_log_to_trace_csv.py \
      --log "$LOG_FILE" \
      --csv "$CSV_FILE"
    cd verif/sim
  else
    echo " [ERROR] Verilator log file does not exist: $LOG_FILE"
  fi
fi

# ================================================================
# 5. Compile for Spike
# ================================================================
if [ "$RUN_SPIKE" = true ]; then
  echo ">>> Compiling for Spike with ASM file: $ASM_FILE"

  $RISCV_GCC \
    ../tests/custom/mptw_test/s_function.S \
    ../tests/custom/common/syscalls.c \
    ../tests/custom/common/crt.S \
    ../tests/custom/mptw_test/mptw_test.c \
    ../regress/verif/tests/riscv-arch-test/riscv-test-suite/rv64i_m/I/src/"$ASM_FILE" \
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

  # Run Spike simulation
  python3 cva6.py \
    --target cv64a6_imafdch_sv39 \
    --iss=spike \
    --iss_yaml=cva6.yaml \
    --elf_tests=out/mptw_test.o \
    --linker=$LINKER \
    --steps=iss_sim

  cd ../../

  # Convert Spike log to CSV
  LOG_FILE=verif/sim/${OUT_DIR}/spike_sim/mptw_test.cv64a6_imafdch_sv39.log
  CSV_FILE=verif/sim/${OUT_DIR}/spike_sim/mptw_test.cv64a6_imafdch_sv39.csv

  if [ -f "$LOG_FILE" ]; then
    PYTHONPATH=verif/sim/dv/scripts python3 verif/sim/cva6_spike_log_to_trace_csv.py \
      --log "$LOG_FILE" \
      --csv "$CSV_FILE"
  else
    echo "[ERROR] Spike log file does not exist: $LOG_FILE"
  fi
fi

cd verif/sim
# ================================================================
# 6. Compare results (if both ran)
# ================================================================
if [ "$RUN_VERI" = true ] && [ "$RUN_SPIKE" = true ]; then
  PYTHONPATH=dv/scripts python3 compare_csv_only.py
fi
