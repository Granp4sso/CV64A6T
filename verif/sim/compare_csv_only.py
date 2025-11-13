#!/usr/bin/env python3
import os
import sys
from datetime import date

# Add DV scripts directory to PYTHONPATH
root_dir = os.path.abspath(os.path.join(os.path.dirname(__file__), ".."))
dv_scripts = os.path.join(root_dir, "dv", "scripts")
sys.path.insert(0, dv_scripts)

# Correct import (new location)
from instr_trace_compare import compare_trace_csv

# Automatically detect today's output folder
today = date.today().strftime("out_%Y-%m-%d")

# Paths to CSVs and report
veri_csv = f"{today}/veri-testharness_sim/mptw_test.cv64a6_imafdch_sv39.csv"
spike_csv = f"{today}/spike_sim/mptw_test.cv64a6_imafdch_sv39.csv"
report = f"{today}/iss_regr.log"

print(f"Comparing:\n  {veri_csv}\n  {spike_csv}\n")

# Perform comparison
result = compare_trace_csv(veri_csv, spike_csv, "veri-testharness", "spike", report)
print(result)

