# UW-GS: Distractor-Aware 3D Gaussian Splatting for Enhanced Underwater Scene Reconstruction

[![WACV 2025](https://img.shields.io/badge/WACV-2025-blue)](https://openaccess.thecvf.com/content/WACV2025/html/Wang_UW-GS_Distractor-Aware_3D_Gaussian_Splatting_for_Enhanced_Underwater_Scene_Reconstruction_WACV_2025_paper.html)
[![arXiv](https://img.shields.io/badge/arXiv-2410.01517-b31b1b.svg)](https://arxiv.org/abs/2410.01517)

Official implementation of **UW-GS**, accepted by the IEEE/CVF Winter Conference on Applications of Computer Vision (**WACV 2025**).

**Authors:** Haoran Wang, Nantheera Anantrasirichai, Fan Zhang, and David Bull<br>
University of Bristol

UW-GS adapts 3D Gaussian Splatting to underwater scenes affected by wavelength-dependent attenuation, backscatter, and moving distractors. It combines a distance-aware underwater appearance model, physics-guided density control, depth supervision, and a binary motion mask for robust reconstruction.

## Installation

The provided environment targets Python 3.7, PyTorch 1.12.1, and CUDA 11.6.

```bash
git clone https://github.com/WangHaoran16/UW-GS.git
cd UW-GS
conda env create -f environment.yml
conda activate UW-GS
```

Install any remaining runtime dependencies when needed:

```bash
pip install imageio==2.27.0 opencv-python imageio-ffmpeg scipy dearpygui lpips
```

A working CUDA compiler compatible with the installed PyTorch version is required to build the differentiable rasterizer and KNN extension.

## Dataset Preparation

UW-GS expects a COLMAP scene with RGB images and aligned pseudo-depth maps:

```text
scene/
|-- images/
|-- depthmap/
`-- sparse/
    `-- 0/
        |-- cameras.bin
        |-- images.bin
        `-- points3D.bin
```

Each depth map must have the same filename as its corresponding RGB image. The loader supports undistorted `PINHOLE` and `SIMPLE_PINHOLE` COLMAP cameras.

To prepare a new image collection with COLMAP, use:

```bash
python convert.py -s /path/to/scene
```

## Training

Train UW-GS with the default configuration:

```bash
python train.py -s /path/to/scene -m output/scene
```

Enable the binary motion mask for scenes containing moving distractors:

```bash
python train.py -s /path/to/scene -m output/scene --BMM_Flag
```

The default configuration trains for 15,000 iterations. Common options include:

```text
--iterations              Number of training iterations
--resolution, -r          Input resolution or downsampling factor
--depth_threshold         Physics-guided density-control threshold
--BMM_Flag                Enable binary motion masking
--start_checkpoint        Resume from a checkpoint
```

## Rendering

Render the trained model:

```bash
python render.py -m output/scene --iteration 15000
```

Render only the test views:

```bash
python render.py -m output/scene --iteration 15000 --skip_train
```

Rendered RGB images, ground truth, depth, alpha, error maps, and clean-color estimates are saved under the model directory.

## Evaluation

Compute SSIM, PSNR, and LPIPS:

```bash
python metrics.py -m output/scene
```

The results are also written to `results.json` and `per_view.json` in the model directory.

## Citation

If this work is useful for your research, please cite:

```bibtex
@inproceedings{wang2025uwgs,
  title     = {UW-GS: Distractor-Aware 3D Gaussian Splatting for Enhanced Underwater Scene Reconstruction},
  author    = {Wang, Haoran and Anantrasirichai, Nantheera and Zhang, Fan and Bull, David},
  booktitle = {Proceedings of the IEEE/CVF Winter Conference on Applications of Computer Vision},
  pages     = {3280--3289},
  year      = {2025}
}
```

## Acknowledgements

This project is built on the official [3D Gaussian Splatting](https://github.com/graphdeco-inria/gaussian-splatting) implementation.

## License

This software is available for non-commercial research and evaluation use under the terms in [LICENSE.md](LICENSE.md).
