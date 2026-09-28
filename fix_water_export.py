import re

with open('Codebase/scripts/run_pipeline.sh', 'r') as f:
    content = f.read()

# Add ns-export to Stage 4 for watersplatting
old_train = '''            watersplatting)
                run_stage_command "water_splatting" "${REPO_ROOT}/Codebase/3DGS-Water-Approaches/Image/water-splatting-main" \\
                    ns-train water-splatting --experiment-name "${scene_name}" --vis viewer+wandb colmap --downscale-factor 1 --eval-mode interval --eval-interval 8 --colmap-path sparse/0 --data "${scene_path}" --images-path images
                ;;'''

new_train = '''            watersplatting)
                run_stage_command "water_splatting" "${REPO_ROOT}/Codebase/3DGS-Water-Approaches/Image/water-splatting-main" \\
                    ns-train water-splatting --experiment-name "${scene_name}" --vis viewer+wandb colmap --downscale-factor 1 --eval-mode interval --eval-interval 8 --colmap-path sparse/0 --data "${scene_path}" --images-path images
                local ws_output_dir="${REPO_ROOT}/Codebase/3DGS-Water-Approaches/Image/water-splatting-main/outputs/${scene_name}/water-splatting"
                local config_path
                config_path="$(find "${ws_output_dir}" -name 'config.yml' | sort -r | head -n 1 2>/dev/null || true)"
                if [[ -n "${config_path}" ]]; then
                    local run_dir
                    run_dir="$(dirname "${config_path}")"
                    log_info "Exporting WaterSplatting to .ply for visualization and SuGaR:"
                    run_stage_command "water_splatting" "${REPO_ROOT}/Codebase/3DGS-Water-Approaches/Image/water-splatting-main" \\
                        ns-export gaussian-splat --load-config "${config_path}" --output-dir "${run_dir}/export"
                fi
                ;;'''

content = content.replace(old_train, new_train)

# Remove ns-export from Stage 6
old_eval = '''            log_info "Evaluating WaterSplatting with config: ${config_path}"
            run_stage_command "water_splatting" "${REPO_ROOT}/Codebase/3DGS-Water-Approaches/Image/water-splatting-main" \\
                ns-eval --load-config "${config_path}" --output-path "${run_dir}/results.json"
            log_info "Exporting WaterSplatting to .ply for visualization:"
            run_stage_command "water_splatting" "${REPO_ROOT}/Codebase/3DGS-Water-Approaches/Image/water-splatting-main" \\
                ns-export gaussian-splat --load-config "${config_path}" --output-dir "${run_dir}/export"'''

new_eval = '''            log_info "Evaluating WaterSplatting with config: ${config_path}"
            run_stage_command "water_splatting" "${REPO_ROOT}/Codebase/3DGS-Water-Approaches/Image/water-splatting-main" \\
                ns-eval --load-config "${config_path}" --output-path "${run_dir}/results.json"'''

content = content.replace(old_eval, new_eval)

with open('Codebase/scripts/run_pipeline.sh', 'w') as f:
    f.write(content)
print("Success")
