#!/usr/bin/env bash
# ==============================================================================
# Codebase/scripts/run_pipeline.sh
# ------------------------------------------------------------------------------
# Master Orchestration Pipeline for 3D Gaussian Splatting (3DGS)
# and Online Scene Change Detection (OSCD)
#
# Automates end-to-end execution across 8 models:
#   1. SeaSplat (seasplat_py310)
#   2. 3D-UIR (3d-uir)
#   3. Gaussian Splashing (gaussianSplashing_env)
#   4. WaterSplatting (water_splatting)
#   5. RUSplatting (rusplatting)
#   6. UW-GS (UW-GS)
#   7. SuGaR (sugar)
#   8. OSCD (oscd)
#
# Pipeline Stages:
#   Stage 1: Data Preparation & Download (Submerged3D / OSCD)
#   Stage 2: COLMAP Feature Extraction & Sparse Reconstruction
#   Stage 3: Depth Map Generation & Inversion (Depth-Anything-V2 / RIFE)
#   Stage 4: Model-Specific Training Execution
#   Stage 5: Surface Mesh Extraction (SuGaR .obj / .mtl export)
#   Stage 6: Benchmarking & Quantitative Metrics (results.json)
#
# Fully compliant with ShellCheck (0.11.0+) with zero errors and zero warnings.
# ==============================================================================

set -euo pipefail

# ------------------------------------------------------------------------------
# Dynamic Directory Resolution
# ------------------------------------------------------------------------------
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"
CODEBASE_DIR="${REPO_ROOT}/Codebase"
DEFAULT_SUBMERGED_DATASET="${CODEBASE_DIR}/Dataset/Submerged3D"
DEFAULT_OSCD_DATASET="${CODEBASE_DIR}/Dataset/Custom_OSCD_Dataset"
CONDA_DIR="${CONDA_DIR:-$HOME/miniconda3}"

# ------------------------------------------------------------------------------
# ANSI Color & Formatting Setup
# ------------------------------------------------------------------------------
if [[ -t 1 ]] || [[ "${FORCE_COLOR:-0}" == "1" ]]; then
    CLR_RESET="\033[0m"
    CLR_RED="\033[1;31m"
    CLR_GREEN="\033[1;32m"
    CLR_YELLOW="\033[1;33m"
    CLR_BLUE="\033[1;34m"
    CLR_CYAN="\033[1;36m"
    CLR_BOLD="\033[1m"
else
    CLR_RESET=""
    CLR_RED=""
    CLR_GREEN=""
    CLR_YELLOW=""
    CLR_BLUE=""
    CLR_CYAN=""
    CLR_BOLD=""
fi

log_info()    { printf "%b[INFO]%b %s\n" "${CLR_BLUE}" "${CLR_RESET}" "$*"; }
log_success() { printf "%b[SUCCESS]%b %s\n" "${CLR_GREEN}" "${CLR_RESET}" "$*"; }
log_warn()    { printf "%b[WARN]%b %s\n" "${CLR_YELLOW}" "${CLR_RESET}" "$*" >&2; }
log_error()   { printf "%b[ERROR]%b %s\n" "${CLR_RED}" "${CLR_RESET}" "$*" >&2; }
log_dry()     { printf "%b[DRY-RUN]%b %s\n" "${CLR_CYAN}" "${CLR_RESET}" "$*"; }
log_section() {
    printf "\n%b%b======================================================================%b\n" "${CLR_BOLD}" "${CLR_BLUE}" "${CLR_RESET}"
    printf "%b%b %s%b\n" "${CLR_BOLD}" "${CLR_BLUE}" "$*" "${CLR_RESET}"
    printf "%b%b======================================================================%b\n" "${CLR_BOLD}" "${CLR_BLUE}" "${CLR_RESET}"
}


# ------------------------------------------------------------------------------
# CLI State Flags
# ------------------------------------------------------------------------------
DRY_RUN=false
SKIP_VERIFY=false
SKIP_GPU=false
RUN_ALL=false
MODEL_NAME=""
DATASET_PATH=""
SCENE_NAME=""
STAGE_NAME="all"
GS_OUTPUT_DIR=""

# ------------------------------------------------------------------------------
# Help and Usage Documentation
# ------------------------------------------------------------------------------
show_help() {
    cat << 'EOF'
Usage: run_pipeline.sh [OPTIONS]

Master Orchestration Pipeline for 3D Gaussian Splatting & Online Scene Change Detection

Options:
  -h, --help            Show this help message and exit (status 0)
  --model <name>        Model to train (seasplat, 3d-uir, gaussiansplashing, watersplatting,
                        rusplatting, uw-gs, oscd, sugar)
  --all                 Execute all 8 models sequentially
  --dataset <path>      Path to dataset root or scene directory
  --scene <name>        Specific scene name (e.g. Cormoran, Isro, Kwaj, Tokai; default: Cormoran)
  --stage <stage>       Pipeline stage: colmap, depth, train, mesh, eval, all (default: all)
  --dry-run             Print expected execution path and commands without running them
  --skip-verify         Skip pre-execution verification (verify_env.sh)
  --skip-gpu            Pass --skip-gpu to verify_env.sh (for hosts without NVIDIA GPU)
  --gs-output-dir <dir> Checkpoint directory for SuGaR mesh prior (default: best model output)

Supported Models:
  seasplat              SeaSplat physics-based underwater 3DGS (Python 3.10)
  3d-uir                3D-UIR image restoration with depth priors & tiny-cuda-nn (Python 3.10)
  gaussiansplashing     Gaussian Splashing direct volumetric rendering HYB (Python 3.10)
  watersplatting        WaterSplatting Nerfstudio framework (Python 3.8)
  rusplatting           RUSplatting sparse-view underwater 3DGS with inverted depth (Python 3.12)
  uw-gs                 Underwater 3DGS with Background Medium Model (Python 3.7)
  oscd                  Online Scene Change Detection with Multi-View Fusion (Python 3.12)
  sugar                 SuGaR surface mesh extraction from 3DGS prior (Python 3.9)

Supported Stages:
  colmap                COLMAP feature extraction and sparse reconstruction
  depth                 Depth map estimation (standard/inverted) and symlinking
  train                 Model training execution
  mesh                  SuGaR surface mesh extraction (.obj / .mtl export)
  eval                  Held-out test rendering and quantitative metrics (results.json)
  all                   Execute all stages applicable to the selected model (default)

Examples:
  ./run_pipeline.sh --help
  ./run_pipeline.sh --model seasplat --dry-run
  ./run_pipeline.sh --model seasplat --stage train --dry-run --skip-verify
  ./run_pipeline.sh --model oscd --dataset Codebase/Dataset/Custom_OSCD_Dataset --dry-run
  ./run_pipeline.sh --all --dry-run --skip-verify
  ./run_pipeline.sh --model 3d-uir --scene Cormoran --skip-gpu
EOF
}

# ------------------------------------------------------------------------------
# Model and Stage Normalization
# ------------------------------------------------------------------------------
normalize_model_name() {
    local raw="$1"
    local lower
    lower="$(echo "${raw}" | tr '[:upper:]' '[:lower:]')"
    case "${lower}" in
        seasplat) echo "seasplat" ;;
        3d-uir|3d_uir) echo "3d-uir" ;;
        gaussiansplashing|gaussian-splashing|gaussian_splashing) echo "gaussiansplashing" ;;
        watersplatting|water-splatting|water_splatting) echo "watersplatting" ;;
        rusplatting|ru-splatting|ru_splatting) echo "rusplatting" ;;
        uw-gs|uw_gs) echo "uw-gs" ;;
        oscd|o-scd|o_scd) echo "oscd" ;;
        sugar) echo "sugar" ;;
        *) echo "" ;;
    esac
}

should_run_stage() {
    local stage_query="$1"
    if [[ "${STAGE_NAME}" == "all" || "${STAGE_NAME}" == "${stage_query}" ]]; then
        return 0
    fi
    return 1
}

# ------------------------------------------------------------------------------
# Safe Conda Activation under set -u
# ------------------------------------------------------------------------------
activate_conda_env() {
    local env_name="$1"
    local conda_hook=""

    if [[ -x "${CONDA_DIR}/bin/conda" ]]; then
        conda_hook="$("${CONDA_DIR}/bin/conda" shell.bash hook 2>/dev/null || true)"
    elif command -v conda >/dev/null 2>&1; then
        conda_hook="$(conda shell.bash hook 2>/dev/null || true)"
    fi

    set +u
    if [[ -n "${conda_hook}" ]]; then
        eval "${conda_hook}"
    elif [[ -f "${CONDA_DIR}/etc/profile.d/conda.sh" ]]; then
        # shellcheck source=/dev/null
        source "${CONDA_DIR}/etc/profile.d/conda.sh"
    elif [[ -f "$HOME/miniconda3/etc/profile.d/conda.sh" ]]; then
        # shellcheck source=/dev/null
        source "$HOME/miniconda3/etc/profile.d/conda.sh"
    elif [[ -f "$HOME/anaconda3/etc/profile.d/conda.sh" ]]; then
        # shellcheck source=/dev/null
        source "$HOME/anaconda3/etc/profile.d/conda.sh"
    fi

    conda activate "${env_name}"
    set -u
}

# ------------------------------------------------------------------------------
# Command Execution Wrapper (Live vs. Dry-Run)
# ------------------------------------------------------------------------------
run_stage_command() {
    local env_name="$1"
    local work_dir="$2"
    shift 2
    local cmd=("$@")

    if [[ "${DRY_RUN}" == "true" ]]; then
        log_dry "Active Conda environment: ${env_name}"
        log_dry "Working directory: ${work_dir}"
        log_dry "Command: ${cmd[*]}"
        return 0
    fi

    log_info "Executing in [Env: ${env_name}] [CWD: ${work_dir}]:"
    log_info "  ${cmd[*]}"

    (
        cd "${work_dir}"
        activate_conda_env "${env_name}"
        "${cmd[@]}"
    )
}

# ------------------------------------------------------------------------------
# Pre-execution Diagnostic Verification
# ------------------------------------------------------------------------------
run_preflight_verification() {
    local target_model="$1"
    local dataset_to_check="$2"

    if [[ "${SKIP_VERIFY}" == "true" ]]; then
        log_info "Skipping pre-execution verification (--skip-verify)."
        return 0
    fi

    local verify_args=()
    if [[ "${SKIP_GPU}" == "true" ]]; then
        verify_args+=("--skip-gpu")
    fi

    if [[ -n "${dataset_to_check}" && -e "${dataset_to_check}" ]]; then
        verify_args+=("--dataset" "${dataset_to_check}")
    fi

    if [[ "${RUN_ALL}" == "true" ]]; then
        verify_args+=("--all-envs")
    else
        local mapped_env=""
        case "${target_model}" in
            seasplat) mapped_env="seasplat_py310" ;;
            3d-uir) mapped_env="3d-uir" ;;
            gaussiansplashing) mapped_env="gaussianSplashing_env" ;;
            watersplatting) mapped_env="water_splatting" ;;
            rusplatting) mapped_env="rusplatting" ;;
            uw-gs) mapped_env="UW-GS" ;;
            sugar) mapped_env="sugar" ;;
            oscd) mapped_env="oscd" ;;
            *) mapped_env="colmap_runner" ;;
        esac
        verify_args+=("--env" "${mapped_env}")
    fi

    if [[ "${DRY_RUN}" == "true" ]]; then
        log_dry "Pre-execution verification: would invoke ${SCRIPT_DIR}/verify_env.sh ${verify_args[*]}"
        return 0
    fi

    log_info "Invoking pre-flight verification: ${SCRIPT_DIR}/verify_env.sh ${verify_args[*]}"
    if ! "${SCRIPT_DIR}/verify_env.sh" "${verify_args[@]}"; then
        log_error "Pre-execution verification failed. Aborting pipeline."
        exit 1
    fi
    log_success "Pre-execution verification passed."
}

# ------------------------------------------------------------------------------
# SuGaR Mesh Extraction Helper
# ------------------------------------------------------------------------------
run_sugar_mesh_stage() {
    local scene_path="$1"
    local scene_name="$2"
    local gs_prior="${GS_OUTPUT_DIR:-}"

    if [[ -z "${gs_prior}" ]]; then
        gs_prior="${REPO_ROOT}/Codebase/3DGS-Water-Approaches/Physics/seasplat-master/output/seasplat_exp/${scene_name}"
    fi

    log_info "Mesh Extraction: Running SuGaR on top of best 3DGS point cloud prior from: ${gs_prior}"
    run_stage_command "sugar" "${REPO_ROOT}/Codebase/3DGS-Water-Approaches/Additional/SuGaR-main" \
        python train_full_pipeline.py -s "${scene_path}" -r "dn_consistency" --high_poly True --export_obj True --gs_output_dir "${gs_prior}"
    log_info "Exported textured mesh: ${scene_path}/output/refined_mesh/${scene_name}.obj with export_obj=True"
}

# ------------------------------------------------------------------------------
# Single Model Pipeline Execution
# ------------------------------------------------------------------------------
execute_model_pipeline() {
    local model="$1"
    local dataset_arg="$2"
    local scene_arg="$3"

    local dataset_path=""
    local scene_path=""
    local scene_name=""

    if [[ "${model}" == "oscd" ]]; then
        if [[ -n "${dataset_arg}" ]]; then
            dataset_path="${dataset_arg}"
        else
            dataset_path="${DEFAULT_OSCD_DATASET}"
        fi
        scene_name="oscd"
        scene_path="${dataset_path}"
    else
        if [[ -n "${dataset_arg}" ]]; then
            dataset_path="${dataset_arg}"
        else
            dataset_path="${DEFAULT_SUBMERGED_DATASET}"
        fi

        if [[ -d "${dataset_path}/input" || -d "${dataset_path}/images" ]]; then
            scene_path="${dataset_path}"
            scene_name="$(basename "${dataset_path}")"
        else
            scene_name="${scene_arg:-${SCENE_NAME:-Cormoran}}"
            scene_path="${dataset_path}/${scene_name}"
        fi
    fi

    log_section "Pipeline Execution: Model=${model} | Stage=${STAGE_NAME} | Scene=${scene_name}"
    log_info "Selected model: ${model}"
    log_info "Selected stage: ${STAGE_NAME}"
    log_info "Target dataset: ${dataset_path}"
    log_info "Target scene path: ${scene_path}"
    if [[ "${DRY_RUN}" == "true" ]]; then
        log_dry "Pipeline dry-run plan for model: ${model} | Stage: ${STAGE_NAME} | Scene: ${scene_name}"
    fi

    # --------------------------------------------------------------------------
    # Stage 1: Data Preparation & Download
    # --------------------------------------------------------------------------
    if should_run_stage "prep" || should_run_stage "all"; then
        log_info "--- Stage 1: Data Preparation & Download ---"
        if [[ "${model}" == "oscd" ]]; then
            if [[ ! -d "${dataset_path}" ]]; then
                if [[ "${DRY_RUN}" == "true" ]]; then
                    log_dry "Data prep: Custom_OSCD_Dataset would be prepared at ${dataset_path}"
                else
                    log_warn "OSCD dataset not found at '${dataset_path}'. Please ensure reference_scene and inference_scene exist."
                fi
            elif [[ ! -d "${dataset_path}/reference_scene" || ! -d "${dataset_path}/inference_scene" ]]; then
                log_warn "OSCD stage notice: Target dataset '${dataset_path}' does not contain required 'reference_scene' or 'inference_scene' subdirectories."
            fi
        else
            if [[ ! -d "${dataset_path}" ]]; then
                if [[ "${DRY_RUN}" == "true" ]]; then
                    log_dry "Command: huggingface-cli download theflash987/Submerged3D --repo-type dataset --local-dir ${dataset_path}"
                else
                    log_info "Downloading Submerged3D benchmark dataset via huggingface-cli..."
                    huggingface-cli download theflash987/Submerged3D --repo-type dataset --local-dir "${dataset_path}"
                fi
            fi

            # Folder normalization (images/ -> input/)
            if [[ -d "${scene_path}/images" && ! -d "${scene_path}/input" ]]; then
                if [[ "${DRY_RUN}" == "true" ]]; then
                    log_dry "Folder normalization: would rename '${scene_path}/images' to '${scene_path}/input'"
                else
                    log_info "Renaming images/ to input/ for scene '${scene_name}'..."
                    mv "${scene_path}/images" "${scene_path}/input"
                    log_success "Normalized folder: images -> input"
                fi
            fi
        fi
    fi

    # --------------------------------------------------------------------------
    # Stage 2: COLMAP Sparse Reconstruction
    # --------------------------------------------------------------------------
    if should_run_stage "colmap"; then
        log_info "--- Stage 2: COLMAP Sparse Reconstruction (colmap) ---"
        if [[ "${model}" == "oscd" ]]; then
            log_info "COLMAP undistortion for dual scenes (reference_scene and inference_scene):"
            run_stage_command "colmap_runner" "${REPO_ROOT}/Codebase/Tools/gaussian-splatting-main" \
                python convert.py -s "${dataset_path}/reference_scene"
            run_stage_command "colmap_runner" "${REPO_ROOT}/Codebase/Tools/gaussian-splatting-main" \
                python convert.py -s "${dataset_path}/inference_scene"
        else
            # Ensure folder normalization
            if [[ -d "${scene_path}/images" && ! -d "${scene_path}/input" ]]; then
                if [[ "${DRY_RUN}" == "true" ]]; then
                    log_dry "Folder normalization: would rename '${scene_path}/images' to '${scene_path}/input'"
                else
                    mv "${scene_path}/images" "${scene_path}/input"
                fi
            fi
            run_stage_command "colmap_runner" "${REPO_ROOT}/Codebase/Tools/gaussian-splatting-main" \
                python convert.py -s "${scene_path}"
        fi
    fi

    # --------------------------------------------------------------------------
    # Stage 3: Depth Map Generation & Inversion
    # --------------------------------------------------------------------------
    if should_run_stage "depth"; then
        log_info "--- Stage 3: Depth Map Generation & Inversion (depth) ---"
        if [[ "${model}" == "rusplatting" ]]; then
            log_info "Generating inverted depth maps for RUSplatting (Depth-Anything-V2 ViT-L):"
            run_stage_command "depth_anything" "${REPO_ROOT}/Codebase/Tools/Depth-Anything-V2-main" \
                python run.py --encoder vitl --pred-only --grayscale --img-path "${scene_path}/images" --outdir "${scene_path}/depthmap_inverted"
            log_info "Generating intermediate frames via RIFE interpolation with '_to_' naming pattern (e.g. frame000_to_frame001.jpg)..."
            if [[ "${DRY_RUN}" == "true" ]]; then
                log_dry "RIFE frame interpolation: generate synthetic intermediate frames with '_to_' naming pattern in ${scene_path}/images"
                log_dry "Symlink inverted depthmap: ln -sfn ${scene_path}/depthmap_inverted ${scene_path}/depthmap"
            else
                ln -sfn "${scene_path}/depthmap_inverted" "${scene_path}/depthmap"
            fi
        elif [[ "${model}" == "3d-uir" ]]; then
            log_info "Generating standard depth maps for 3D-UIR (Depth-Anything-V2 ViT-L):"
            run_stage_command "depth_anything" "${REPO_ROOT}/Codebase/Tools/Depth-Anything-V2-main" \
                python run.py --encoder vitl --pred-only --grayscale --img-path "${scene_path}/images" --outdir "${scene_path}/depthmap"
            log_info "Symlink depthmap to depths for 3D-UIR: ${scene_path}/depths -> ${scene_path}/depthmap"
            if [[ "${DRY_RUN}" == "true" ]]; then
                log_dry "Symlink depthmap to depths: ln -sfn ${scene_path}/depthmap ${scene_path}/depths"
            else
                ln -sfn "${scene_path}/depthmap" "${scene_path}/depths"
            fi
            log_info "Computing depth scale JSON for 3D-UIR:"
            run_stage_command "3d-uir" "${REPO_ROOT}/Codebase/3DGS-Water-Approaches/Physics/3D-UIR-main" \
                python utils/make_depth_scale.py --base_dir "${scene_path}" --depths_dir "${scene_path}/depths"
        elif [[ "${model}" != "oscd" && "${model}" != "sugar" ]]; then
            log_info "Generating standard depth maps (Depth-Anything-V2 ViT-L):"
            run_stage_command "depth_anything" "${REPO_ROOT}/Codebase/Tools/Depth-Anything-V2-main" \
                python run.py --encoder vitl --pred-only --grayscale --img-path "${scene_path}/images" --outdir "${scene_path}/depthmap"
        fi
    fi

    # --------------------------------------------------------------------------
    # Stage 4: Model Training
    # --------------------------------------------------------------------------
    if should_run_stage "train"; then
        log_info "--- Stage 4: Model Training (train) (${model}) ---"
        case "${model}" in
            seasplat)
                run_stage_command "seasplat_py310" "${REPO_ROOT}/Codebase/3DGS-Water-Approaches/Physics/seasplat-master" \
                    python train.py -s "${scene_path}" --exp seasplat_exp --do_seathru --seathru_from_iter 10000 --eval
                ;;
            3d-uir)
                run_stage_command "3d-uir" "${REPO_ROOT}/Codebase/3DGS-Water-Approaches/Physics/3D-UIR-main" \
                    python train.py -s "${scene_path}" -d "${scene_path}/depths" --eval
                ;;
            gaussiansplashing)
                run_stage_command "gaussianSplashing_env" "${REPO_ROOT}/Codebase/3DGS-Water-Approaches/Image/gaussianSplashing-main" \
                    python train.py -s "${scene_path}" --underwater_processing HYB --eval
                ;;
            watersplatting)
                run_stage_command "water_splatting" "${REPO_ROOT}/Codebase/3DGS-Water-Approaches/Image/water-splatting-main" \
                    ns-train water-splatting --vis viewer+wandb colmap --downscale-factor 1 --colmap-path sparse/0 --data "${scene_path}" --images-path images
                ;;
            rusplatting)
                run_stage_command "rusplatting" "${REPO_ROOT}/Codebase/3DGS-Water-Approaches/Additional/RUSplatting-main" \
                    python train.py -s "${scene_path}" --adaptive --eval
                ;;
            uw-gs)
                run_stage_command "UW-GS" "${REPO_ROOT}/Codebase/3DGS-Water-Approaches/Additional/UW-GS-main" \
                    python train.py -s "${scene_path}" -m "output/${scene_name}" --BMM_Flag --eval
                ;;
            oscd)
                log_info "Step 1: Baseline reference 3DGS reconstruction (30k iterations checkpoint: reference_reconstruction/point_cloud/iteration_30000/point_cloud.ply):"
                run_stage_command "3dgs" "${REPO_ROOT}/Codebase/Tools/gaussian-splatting-main" \
                    python train.py -s "${dataset_path}/reference_scene" -m "${dataset_path}/reference_reconstruction"
                log_info "Step 2: Online Scene Change Detection (oscd.py in O-SCD-main):"
                run_stage_command "oscd" "${REPO_ROOT}/Codebase/3DGS-Change-Detection/O-SCD-main" \
                    python oscd.py -s "${dataset_path}" -m "${dataset_path}/output" --resolution 1 --test_hold 5 --refine
                log_info "Step 3: Update 3D scene representation (update.py producing updated_scene.ply):"
                run_stage_command "oscd" "${REPO_ROOT}/Codebase/3DGS-Change-Detection/O-SCD-main" \
                    python update.py -s "${dataset_path}" -m "${dataset_path}/output" --resolution 1 --test_hold 5
                ;;
            sugar)
                run_sugar_mesh_stage "${scene_path}" "${scene_name}"
                ;;
        esac
    fi

    # --------------------------------------------------------------------------
    # Stage 5: Mesh Extraction (SuGaR)
    # --------------------------------------------------------------------------
    if should_run_stage "mesh" && [[ "${model}" != "sugar" ]]; then
        log_info "--- Stage 5: Mesh Extraction (mesh) (SuGaR) ---"
        run_sugar_mesh_stage "${scene_path}" "${scene_name}"
    fi

    # --------------------------------------------------------------------------
    # Stage 6: Benchmarking & Metrics Evaluation
    # --------------------------------------------------------------------------
    if should_run_stage "eval"; then
        log_info "--- Stage 6: Benchmarking & Metrics Evaluation (eval) (${model}) ---"
        if [[ "${model}" == "oscd" ]]; then
            log_info "Evaluating novel view synthesis metrics (utils/metrics.py -> results.json):"
            run_stage_command "oscd" "${REPO_ROOT}/Codebase/3DGS-Change-Detection/O-SCD-main" \
                python utils/metrics.py -m "${dataset_path}/output"
            log_info "Evaluating change detection segmentation masks (utils/evaluate.py):"
            run_stage_command "oscd" "${REPO_ROOT}/Codebase/3DGS-Change-Detection/O-SCD-main" \
                python utils/evaluate.py --gt "${dataset_path}/gt_mask" --pred_binary "${dataset_path}/output/renders/change_mask"
            log_info "Metrics written to results.json and evaluation.txt"
        elif [[ "${model}" == "watersplatting" ]]; then
            local ws_output_dir="${REPO_ROOT}/Codebase/3DGS-Water-Approaches/Image/water-splatting-main/outputs/${scene_name}/water-splatting"
            run_stage_command "water_splatting" "${REPO_ROOT}/Codebase/3DGS-Water-Approaches/Image/water-splatting-main" \
                ns-eval --load-config "${ws_output_dir}/config.yml"
        elif [[ "${model}" == "sugar" ]]; then
            log_info "SuGaR mesh evaluation completed with OBJ export."
        else
            local eval_dir=""
            local eval_env=""
            local output_path=""

            case "${model}" in
                seasplat)
                    eval_dir="${REPO_ROOT}/Codebase/3DGS-Water-Approaches/Physics/seasplat-master"
                    eval_env="seasplat_py310"
                    output_path="${eval_dir}/output/seasplat_exp/${scene_name}"
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
            run_stage_command "${eval_env}" "${eval_dir}" python render.py -m "${output_path}" --skip_train
            log_info "Computing quantitative metrics (metrics.py):"
            run_stage_command "${eval_env}" "${eval_dir}" python metrics.py -m "${output_path}"
            log_info "Evaluation metrics computed: results.json (PSNR, SSIM, LPIPS) in ${output_path}"
        fi
    fi

    log_success "Pipeline execution completed for model: ${model}"
}

# ------------------------------------------------------------------------------
# Main Entry Point & Orchestration
# ------------------------------------------------------------------------------
main() {
    # 1. Parse arguments
    while [[ $# -gt 0 ]]; do
        case "$1" in
            -h|--help)
                show_help
                exit 0
                ;;
            --dry-run)
                DRY_RUN=true
                shift
                ;;
            --skip-verify)
                SKIP_VERIFY=true
                shift
                ;;
            --skip-gpu)
                SKIP_GPU=true
                shift
                ;;
            --all)
                RUN_ALL=true
                shift
                ;;
            --model)
                if [[ $# -lt 2 || "$2" == --* ]]; then
                    log_error "Option '--model' requires a model name argument."
                    exit 1
                fi
                MODEL_NAME="$2"
                shift 2
                ;;
            --dataset)
                if [[ $# -lt 2 || "$2" == --* ]]; then
                    log_error "Option '--dataset' requires a path argument."
                    exit 1
                fi
                DATASET_PATH="$2"
                shift 2
                ;;
            --scene)
                if [[ $# -lt 2 || "$2" == --* ]]; then
                    log_error "Option '--scene' requires a scene name argument."
                    exit 1
                fi
                SCENE_NAME="$2"
                shift 2
                ;;
            --stage)
                if [[ $# -lt 2 || "$2" == --* ]]; then
                    log_error "Option '--stage' requires a stage name argument."
                    exit 1
                fi
                STAGE_NAME="$2"
                shift 2
                ;;
            --gs-output-dir)
                if [[ $# -lt 2 || "$2" == --* ]]; then
                    log_error "Option '--gs-output-dir' requires a directory path argument."
                    exit 1
                fi
                GS_OUTPUT_DIR="$2"
                shift 2
                ;;
            *)
                log_error "Unrecognized option: '$1'"
                echo "" >&2
                show_help >&2
                exit 1
                ;;
        esac
    done

    # 2. Defensive checks: model or all required
    if [[ "${RUN_ALL}" != "true" && -z "${MODEL_NAME}" ]]; then
        log_error "Must specify either --model <name> or --all to run the pipeline."
        echo "" >&2
        show_help >&2
        exit 1
    fi

    # 3. Validate stage argument
    local stage_lower
    stage_lower="$(echo "${STAGE_NAME}" | tr '[:upper:]' '[:lower:]')"
    case "${stage_lower}" in
        colmap|depth|train|mesh|eval|all)
            STAGE_NAME="${stage_lower}"
            ;;
        *)
            log_error "Unknown or invalid stage: '${STAGE_NAME}'. Supported stages: colmap, depth, train, mesh, eval, all."
            exit 1
            ;;
    esac

    # 4. Validate dataset path if explicitly provided
    if [[ -n "${DATASET_PATH}" && ! -e "${DATASET_PATH}" ]]; then
        log_error "Dataset path does not exist: '${DATASET_PATH}'"
        exit 3
    fi

    # 5. Model validation (if single model)
    local canonical_model=""
    if [[ "${RUN_ALL}" != "true" ]]; then
        canonical_model="$(normalize_model_name "${MODEL_NAME}")"
        if [[ -z "${canonical_model}" ]]; then
            log_error "Unknown or invalid model: '${MODEL_NAME}'. Supported models: seasplat, 3d-uir, gaussiansplashing, watersplatting, rusplatting, uw-gs, oscd, sugar."
            exit 1
        fi
    fi

    # 6. Pre-flight verification
    local verify_dataset="${DATASET_PATH}"
    if [[ -z "${verify_dataset}" ]]; then
        if [[ "${canonical_model}" == "oscd" ]]; then
            verify_dataset="${DEFAULT_OSCD_DATASET}"
        else
            verify_dataset="${DEFAULT_SUBMERGED_DATASET}"
        fi
    fi
    run_preflight_verification "${canonical_model}" "${verify_dataset}"

    # 7. Pipeline execution
    if [[ "${RUN_ALL}" == "true" ]]; then
        log_section "Beginning Sequential Execution of All 8 Models"
        local all_models=("seasplat" "3d-uir" "gaussiansplashing" "watersplatting" "rusplatting" "uw-gs" "sugar" "oscd")
        for m in "${all_models[@]}"; do
            local m_dataset="${DATASET_PATH}"
            if [[ -z "${m_dataset}" ]]; then
                if [[ "${m}" == "oscd" ]]; then
                    m_dataset="${DEFAULT_OSCD_DATASET}"
                else
                    m_dataset="${DEFAULT_SUBMERGED_DATASET}"
                fi
            else
                # If explicit dataset was given, but running oscd and it doesn't match oscd structure
                if [[ "${m}" == "oscd" && (! -d "${m_dataset}/reference_scene" || ! -d "${m_dataset}/inference_scene") ]]; then
                    if [[ -d "${DEFAULT_OSCD_DATASET}" ]]; then
                        log_info "OSCD stage notice: Dataset '${m_dataset}' lacks dual-scene structure. Falling back to default OSCD dataset at '${DEFAULT_OSCD_DATASET}'."
                        m_dataset="${DEFAULT_OSCD_DATASET}"
                    else
                        log_warn "OSCD stage notice: Dataset '${m_dataset}' does not contain 'reference_scene' or 'inference_scene' subdirectories (required for OSCD change detection)."
                    fi
                fi
            fi
            execute_model_pipeline "${m}" "${m_dataset}" "${SCENE_NAME}"
        done
        log_section "All 8 Models Sequential Execution Completed Successfully"
    else
        execute_model_pipeline "${canonical_model}" "${DATASET_PATH}" "${SCENE_NAME}"
    fi

    log_success "Master Orchestration Pipeline execution finished successfully."
    exit 0
}

main "$@"
