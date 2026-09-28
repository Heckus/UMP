with open('HPC/scripts/run_pipeline.pbs', 'r') as f:
    content = f.read()

old_logic = '''# Path to the core automation script
PIPELINE_SCRIPT="../../Codebase/scripts/run_pipeline.sh"'''

new_logic = '''# Path to the core automation script
# Robust path resolution to handle execution from repository root or HPC/scripts/
if [ -f "Codebase/scripts/run_pipeline.sh" ]; then
    PIPELINE_SCRIPT="$PBS_O_WORKDIR/Codebase/scripts/run_pipeline.sh"
elif [ -f "../../Codebase/scripts/run_pipeline.sh" ]; then
    PIPELINE_SCRIPT="$PBS_O_WORKDIR/../../Codebase/scripts/run_pipeline.sh"
else
    echo "Error: Could not locate Codebase/scripts/run_pipeline.sh from $PBS_O_WORKDIR"
    exit 1
fi'''

content = content.replace(old_logic, new_logic)

with open('HPC/scripts/run_pipeline.pbs', 'w') as f:
    f.write(content)
print("Success")
