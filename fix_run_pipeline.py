import re

with open('Codebase/scripts/run_pipeline.sh', 'r') as f:
    content = f.read()

old_func = '''    if [[ -z "${gs_prior}" ]]; then
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

    log_info "Mesh Extraction: Running SuGaR on top of best 3DGS point cloud prior from: ${gs_prior}"'''

new_func = '''    if [[ -z "${gs_prior}" ]]; then
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
            oscd) gs_prior="${REPO_ROOT}/Codebase/3DGS-Change-Detection/O-SCD-main/output/$(basename "${scene_path}")/output" ;;
            *) gs_prior="${REPO_ROOT}/Codebase/3DGS-Water-Approaches/Physics/seasplat-master/output/${scene_name}" ;;
        esac
    fi

    # Prepare gs_prior for SuGaR: it hardcodes looking for point_cloud/iteration_7000/point_cloud.ply
    if [[ -n "${gs_prior}" && -d "${gs_prior}" ]]; then
        local sugar_ply_dir="${gs_prior}/point_cloud/iteration_7000"
        if [[ ! -f "${sugar_ply_dir}/point_cloud.ply" ]]; then
            mkdir -p "${sugar_ply_dir}"
            local found_ply=""
            if [[ -f "${gs_prior}/point_cloud/iteration_30000/point_cloud.ply" ]]; then
                found_ply="${gs_prior}/point_cloud/iteration_30000/point_cloud.ply"
            elif [[ -f "${gs_prior}/updated_scene.ply" ]]; then
                found_ply="${gs_prior}/updated_scene.ply"
            elif [[ -f "${gs_prior}/splat.ply" ]]; then
                found_ply="${gs_prior}/splat.ply"
            else
                found_ply="$(find "${gs_prior}" -name '*.ply' | head -n 1 || true)"
            fi
            
            if [[ -n "${found_ply}" && -f "${found_ply}" ]]; then
                ln -sfn "${found_ply}" "${sugar_ply_dir}/point_cloud.ply"
                log_info "SuGaR alignment: symlinked ${found_ply} to ${sugar_ply_dir}/point_cloud.ply"
            fi
        fi
    fi

    log_info "Mesh Extraction: Running SuGaR on top of best 3DGS point cloud prior from: ${gs_prior}"'''

content = content.replace(old_func, new_func)

with open('Codebase/scripts/run_pipeline.sh', 'w') as f:
    f.write(content)
print("Success")
