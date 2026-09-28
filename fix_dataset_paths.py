import re

files_to_fix = ['Codebase/scripts/run_pipeline.sh', 'Codebase/scripts/verify_env.sh']

for file in files_to_fix:
    with open(file, 'r') as f:
        content = f.read()
    
    content = content.replace('${CODEBASE_DIR}/Dataset/', '${REPO_ROOT}/Dataset/')
    content = content.replace('Codebase/Dataset/', 'Dataset/')
    
    with open(file, 'w') as f:
        f.write(content)
        
print("Success")
