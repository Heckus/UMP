import re

with open('Codebase/scripts/verify_env.sh', 'r') as f:
    content = f.read()

# Change opt_target_env="" to opt_target_envs=()
content = content.replace('local opt_target_env=""', 'local opt_target_envs=()')

# Change the argument parsing to append to array
content = content.replace('''                opt_target_env="$2"
                shift 2''', '''                opt_target_envs+=("$2")
                shift 2''')

# Change the invocation logic in main
old_invocation = '''    if [[ "${opt_all_envs}" == "true" ]]; then
        check_all_conda_envs || final_exit_code=$?
    elif [[ -n "${opt_target_env}" ]]; then
        check_single_conda_env "${opt_target_env}" || final_exit_code=$?
    fi'''

new_invocation = '''    if [[ "${opt_all_envs}" == "true" ]]; then
        check_all_conda_envs || final_exit_code=$?
    elif [[ ${#opt_target_envs[@]} -gt 0 ]]; then
        for env_to_check in "${opt_target_envs[@]}"; do
            check_single_conda_env "${env_to_check}" || final_exit_code=$?
        done
    fi'''

content = content.replace(old_invocation, new_invocation)

with open('Codebase/scripts/verify_env.sh', 'w') as f:
    f.write(content)

