import re
with open('Codebase/scripts/run_pipeline.sh', 'r') as f:
    content = f.read()

old_eval = '''            local eval_dir=""
            local eval_env=""
            local output_path=""

            case "${model}" in
                seasplat)
                    eval_dir="${REPO_ROOT}/Codebase/3DGS-Water-Approaches/Physics/seasplat-master"
                    eval_env="seasplat_py310"
                    output_path="${eval_dir}/output/${scene_name}"
                    ;;
                3d-uir)
                    eval_dir="${REPO_ROOT}/Codebase/3DGS-Water-Approaches/Physics/3D-UIR-main"
                    eval_env="3d-uir"
                    output_path="${eval_dir}/output/${scene_name}"
                    ;;
                gaussiansplashing)
                    eval_dir="${REPO_ROOT}/Codebase/3DGS-Water-Approaches/Image/gaussianSplashing-main"
                    eval_env="gaussianSplashing_env"
                    output_path="${eval_dir}/output/${scene_name}"
                    ;;
                rusplatting)
                    eval_dir="${REPO_ROOT}/Codebase/3DGS-Water-Approaches/Additional/RUSplatting-main"
                    eval_env="rusplatting"
                    output_path="${eval_dir}/output/${scene_name}"
                    ;;
                uw-gs)
                    eval_dir="${REPO_ROOT}/Codebase/3DGS-Water-Approaches/Additional/UW-GS-main"
                    eval_env="UW-GS"
                    output_path="${eval_dir}/output/${scene_name}"
                    ;;
            esac

            log_info "Running held-out novel view synthesis rendering (render.py):"
            run_stage_command "${eval_env}" "${eval_dir}" python render.py -m "${output_path}" --skip_train'''

new_eval = '''            local eval_dir=""
            local eval_env=""
            local output_path=""
            local render_script="render.py"

            case "${model}" in
                seasplat)
                    eval_dir="${REPO_ROOT}/Codebase/3DGS-Water-Approaches/Physics/seasplat-master"
                    eval_env="seasplat_py310"
                    output_path="${eval_dir}/output/${scene_name}"
                    render_script="render_uw.py"
                    ;;
                3d-uir)
                    eval_dir="${REPO_ROOT}/Codebase/3DGS-Water-Approaches/Physics/3D-UIR-main"
                    eval_env="3d-uir"
                    output_path="${eval_dir}/output/${scene_name}"
                    ;;
                gaussiansplashing)
                    eval_dir="${REPO_ROOT}/Codebase/3DGS-Water-Approaches/Image/gaussianSplashing-main"
                    eval_env="gaussianSplashing_env"
                    output_path="${eval_dir}/output/${scene_name}"
                    ;;
                rusplatting)
                    eval_dir="${REPO_ROOT}/Codebase/3DGS-Water-Approaches/Additional/RUSplatting-main"
                    eval_env="rusplatting"
                    output_path="${eval_dir}/output/${scene_name}"
                    ;;
                uw-gs)
                    eval_dir="${REPO_ROOT}/Codebase/3DGS-Water-Approaches/Additional/UW-GS-main"
                    eval_env="UW-GS"
                    output_path="${eval_dir}/output/${scene_name}"
                    ;;
            esac

            log_info "Running held-out novel view synthesis rendering (${render_script}):"
            run_stage_command "${eval_env}" "${eval_dir}" python "${render_script}" -m "${output_path}" --skip_train'''

content = content.replace(old_eval, new_eval)

with open('Codebase/scripts/run_pipeline.sh', 'w') as f:
    f.write(content)
