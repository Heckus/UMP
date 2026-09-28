import re

with open('Codebase/scripts/run_pipeline.sh', 'r') as f:
    content = f.read()

old_train = '''            oscd)
                log_info "Step 1: Baseline reference 3DGS reconstruction (30k iterations checkpoint: reference_reconstruction/point_cloud/iteration_30000/point_cloud.ply):"
                run_stage_command "3dgs" "${REPO_ROOT}/Codebase/Tools/gaussian-splatting-main" \\
                    python train.py -s "${dataset_path}/reference_scene" -m "${dataset_path}/reference_reconstruction"
                log_info "Step 2: Online Scene Change Detection (oscd.py in O-SCD-main):"
                run_stage_command "oscd" "${REPO_ROOT}/Codebase/3DGS-Change-Detection/O-SCD-main" \\
                    python oscd.py -s "${dataset_path}" -m "${dataset_path}/output" --resolution 1 --test_hold 5 --refine
                log_info "Step 3: Update 3D scene representation (update.py producing updated_scene.ply):"
                run_stage_command "oscd" "${REPO_ROOT}/Codebase/3DGS-Change-Detection/O-SCD-main" \\
                    python update.py -s "${dataset_path}" -m "${dataset_path}/output" --resolution 1 --test_hold 5
                ;;'''

new_train = '''            oscd)
                local oscd_output_base="${REPO_ROOT}/Codebase/3DGS-Change-Detection/O-SCD-main/output/$(basename "${dataset_path}")"
                log_info "Step 1: Baseline reference 3DGS reconstruction (30k iterations checkpoint: reference_reconstruction/point_cloud/iteration_30000/point_cloud.ply):"
                run_stage_command "3dgs" "${REPO_ROOT}/Codebase/Tools/gaussian-splatting-main" \\
                    python train.py -s "${dataset_path}/reference_scene" -m "${oscd_output_base}/reference_reconstruction"
                
                # We need to symlink the reference reconstruction back to the dataset path because oscd.py hardcodes looking for it inside args.source_path
                # "os.path.join(args.source_path, 'reference_reconstruction', ...)"
                if [[ ! -e "${dataset_path}/reference_reconstruction" ]]; then
                    ln -sfn "${oscd_output_base}/reference_reconstruction" "${dataset_path}/reference_reconstruction"
                fi

                log_info "Step 2: Online Scene Change Detection (oscd.py in O-SCD-main):"
                run_stage_command "oscd" "${REPO_ROOT}/Codebase/3DGS-Change-Detection/O-SCD-main" \\
                    python oscd.py -s "${dataset_path}" -m "${oscd_output_base}/output" --resolution 1 --test_hold 5 --refine
                log_info "Step 3: Update 3D scene representation (update.py producing updated_scene.ply):"
                run_stage_command "oscd" "${REPO_ROOT}/Codebase/3DGS-Change-Detection/O-SCD-main" \\
                    python update.py -s "${dataset_path}" -m "${oscd_output_base}/output" --resolution 1 --test_hold 5
                ;;'''

content = content.replace(old_train, new_train)


old_eval = '''        if [[ "${model}" == "oscd" ]]; then
            log_info "Evaluating novel view synthesis metrics (utils/metrics.py -> results.json):"
            run_stage_command "oscd" "${REPO_ROOT}/Codebase/3DGS-Change-Detection/O-SCD-main" \\
                python utils/metrics.py -m "${dataset_path}/output"
            log_info "Evaluating change detection segmentation masks (utils/evaluate.py):"
            run_stage_command "oscd" "${REPO_ROOT}/Codebase/3DGS-Change-Detection/O-SCD-main" \\
                python utils/evaluate.py --gt "${dataset_path}/gt_mask" --pred_binary "${dataset_path}/output/renders/change_mask"
            log_info "Metrics written to results.json and evaluation.txt"'''

new_eval = '''        if [[ "${model}" == "oscd" ]]; then
            local oscd_output_base="${REPO_ROOT}/Codebase/3DGS-Change-Detection/O-SCD-main/output/$(basename "${dataset_path}")"
            log_info "Evaluating novel view synthesis metrics (utils/metrics.py -> results.json):"
            run_stage_command "oscd" "${REPO_ROOT}/Codebase/3DGS-Change-Detection/O-SCD-main" \\
                python utils/metrics.py -m "${oscd_output_base}/output"
            log_info "Evaluating change detection segmentation masks (utils/evaluate.py):"
            run_stage_command "oscd" "${REPO_ROOT}/Codebase/3DGS-Change-Detection/O-SCD-main" \\
                python utils/evaluate.py --gt "${dataset_path}/gt_mask" --pred_binary "${oscd_output_base}/output/renders/change_mask"
            log_info "Metrics written to results.json and evaluation.txt"'''

content = content.replace(old_eval, new_eval)

with open('Codebase/scripts/run_pipeline.sh', 'w') as f:
    f.write(content)
print("Success")
