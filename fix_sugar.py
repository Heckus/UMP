import re

with open('Codebase/scripts/run_pipeline.sh', 'r') as f:
    content = f.read()

old_func = '''run_sugar_mesh_stage() {
    local scene_path="$1"
    local scene_name="$2"
    local gs_prior="${GS_OUTPUT_DIR:-}"

    if [[ -z "${gs_prior}" ]]; then
        gs_prior="${REPO_ROOT}/Codebase/3DGS-Water-Approaches/Physics/seasplat-master/output/${scene_name}"
    fi

    log_info "Mesh Extraction: Running SuGaR on top of best 3DGS point cloud prior from: ${gs_prior}"
    run_stage_command "sugar" "${REPO_ROOT}/Codebase/3DGS-Water-Approaches/Additional/SuGaR-main" \
        python train_full_pipeline.py -s "${scene_path}" -r "dn_consistency" --high_poly True --export_obj True --gs_output_dir "${gs_prior}"
    log_info "Exported textured mesh: ${scene_path}/output/refined_mesh/${scene_name}.obj with export_obj=True"
}'''

new_func = '''run_sugar_mesh_stage() {
    local scene_path="$1"
    local scene_name="$2"
    local current_model="${3:-seasplat}"
    local gs_prior="${GS_OUTPUT_DIR:-}"

    if [[ -z "${gs_prior}" ]]; then
        case "${current_model}" in
            seasplat) gs_prior="${REPO_ROOT}/Codebase/3DGS-Water-Approaches/Physics/seasplat-master/output/${scene_name}" ;;
            3d-uir) gs_prior="${REPO_ROOT}/Codebase/3DGS-Water-Approaches/Physics/3D-UIR-main/output/${scene_name}" ;;
            gaussiansplashing) gs_prior="${REPO_ROOT}/Codebase/3DGS-Water-Approaches/Image/gaussianSplashing-main/output/${scene_name}" ;;
            rusplatting) gs_prior="${REPO_ROOT}/Codebase/3DGS-Water-Approaches/Additional/RUSplatting-main/output/${scene_name}" ;;
            uw-gs) gs_prior="${REPO_ROOT}/Codebase/3DGS-Water-Approaches/Additional/UW-GS-main/output/${scene_name}" ;;
            watersplatting) 
                # Find the latest export from WaterSplatting
                local ws_export_dir="${REPO_ROOT}/Codebase/3DGS-Water-Approaches/Image/water-splatting-main/outputs/${scene_name}/water-splatting"
                gs_prior="$(find "${ws_export_dir}" -name 'export' | sort -r | head -n 1)"
                # If water_splatting hasn't run or doesn't export correctly, fallback
                if [[ -z "${gs_prior}" ]]; then
                    gs_prior="${REPO_ROOT}/Codebase/3DGS-Water-Approaches/Physics/seasplat-master/output/${scene_name}"
                fi
                ;;
            *) gs_prior="${REPO_ROOT}/Codebase/3DGS-Water-Approaches/Physics/seasplat-master/output/${scene_name}" ;;
        esac
    fi

    log_info "Mesh Extraction: Running SuGaR on top of best 3DGS point cloud prior from: ${gs_prior}"
    run_stage_command "sugar" "${REPO_ROOT}/Codebase/3DGS-Water-Approaches/Additional/SuGaR-main" \
        python train_full_pipeline.py -s "${scene_path}" -r "dn_consistency" --high_poly True --export_obj True --gs_output_dir "${gs_prior}"
    log_info "Exported textured mesh: ${scene_path}/output/refined_mesh/${scene_name}.obj with export_obj=True"
}'''

content = content.replace(old_func, new_func)

# Also update the calls to run_sugar_mesh_stage to pass ${model}
content = content.replace('run_sugar_mesh_stage "${scene_path}" "${scene_name}"', 'run_sugar_mesh_stage "${scene_path}" "${scene_name}" "${model}"')

with open('Codebase/scripts/run_pipeline.sh', 'w') as f:
    f.write(content)
print("Success")
