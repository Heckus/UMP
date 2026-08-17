# Advanced Volumetric Reconstruction: A Comprehensive Analysis of 3D Gaussian Splatting and the SeaSplat Architecture

## The Paradigm Shift in Scene Representation: 3D Gaussian Splatting

The domain of novel-view synthesis and volumetric scene reconstruction has undergone a profound transformation with the introduction of 3D Gaussian Splatting (3DGS). Prior to this development, implicit continuous representations—most notably Neural Radiance Fields (NeRFs)—dominated the field of computer vision. While NeRFs achieve extraordinary visual fidelity by utilizing Multi-Layer Perceptrons (MLPs) and volumetric ray-marching, they suffer from prohibitive computational costs during both optimization and inference. The requirement to query the MLP densely along hundreds of sample points per ray makes real-time rendering at high resolutions unattainable without severe quality trade-offs, spatial data structures like hash grids, or complex caching mechanisms. Furthermore, the stochastic sampling required for rendering continuous neural fields often results in noise and temporal instability.

3D Gaussian Splatting resolves this computational bottleneck by substituting the implicit neural network with an explicit, unstructured collection of 3D Gaussian primitives. Each Gaussian acts as a volumetric splat, preserving the continuous, differentiable properties required for gradient-based optimization while enabling highly efficient projection and rasterization on standard graphics hardware. The representation is explicit and unstructured, meaning that the scene is parameterized directly in 3D space without the rigid bounds of a voxel grid or the opaque weight structures of a neural network.

Mathematically, a 3D Gaussian is defined in world space by its center position (mean) $\mu$ and a full 3D covariance matrix $\Sigma$. The evaluation of the Gaussian at any spatial point $x$ is given by:


$$G(x) = e^{-\frac{1}{2}(x - \mu)^T \Sigma^{-1} (x - \mu)}$$

Directly optimizing the covariance matrix $\Sigma$ via stochastic gradient descent presents a mathematical challenge, as covariance matrices possess physical meaning only when they are positive semi-definite. Standard gradient updates can easily violate this constraint, creating invalid matrices. To ensure the covariance matrix remains positive semi-definite during the optimization process, the matrix is parameterized analogously to the configuration of an ellipsoid, utilizing a scaling matrix $S$ (represented by a 3D vector for independent scaling along axes) and a rotation matrix $R$ (represented by a unit quaternion $q$). The covariance is thus computed as:


$$\Sigma = R S S^T R^T$$

Each Gaussian is further parameterized by an opacity value $\alpha$ and a set of Spherical Harmonics (SH) coefficients that encode view-dependent color. The use of Spherical Harmonics allows the representation to accurately model complex, directionally dependent lighting effects, such as specular highlights on shiny surfaces. During the rendering process, these 3D Gaussians must be projected onto the 2D image plane. Given a viewing transformation $W$, the covariance matrix in camera coordinates $\Sigma'$ is calculated using the Jacobian $J$ of the affine approximation of the projective transformation:


$$\Sigma' = J W \Sigma W^T J^T$$

The rasterization pipeline associated with 3DGS is a marvel of parallel GPU engineering. It splits the screen into 16x16 pixel tiles, performs frustum culling to reject primitives outside the view volume, and sorts the Gaussians by depth using a highly parallelized GPU radix sort. This sorting mechanism respects visibility ordering and avoids the expensive per-pixel sorting that hindered previous point-based alpha-blending solutions. The color $C$ of a given pixel is then computed via standard volumetric alpha-blending:


$$C = \sum_{i=1}^{N} c_i \alpha_i \prod_{j=1}^{i-1} (1 - \alpha_j)$$

This explicit representation allows the optimization process to dynamically control the density of the scene. Gaussians with low opacity (typically $\alpha < 0.005$) are periodically pruned to conserve memory. Meanwhile, the optimization algorithm actively identifies under-reconstructed regions—characterized by large view-space positional gradients—and clones the Gaussians to fill in missing geometric features. Conversely, oversized Gaussians in areas of high variance are split into smaller primitives to accurately model fine details without causing "over-reconstruction" artifacts. The result is a scene representation that trains in a fraction of the time required by NeRFs (minutes compared to hours) and renders at upwards of 100 frames per second at 1080p resolution.

---

## Physics-Grounded Underwater Rendering: The SeaSplat Framework

Applying standard 3DGS to underwater environments exposes critical vulnerabilities in the traditional atmospheric rendering paradigm. Water is a participating medium that absorbs and scatters light in a wavelength-dependent and distance-dependent manner. Standard 3DGS, assuming an in-air image formation model, attempts to replicate underwater degradation—such as severe red-light attenuation and hazy backscatter—by placing opaque, unstructured "floater" Gaussians close to the camera. This effectively fills the virtual water column with geometric artifacts that look correct from the training views but completely break down when observed from novel viewpoints.

The SeaSplat framework addresses this fundamental limitation by constraining the 3DGS optimization process with a physically grounded underwater image formation model. By factoring in the optical properties of the water column, SeaSplat simultaneously estimates the true, restored color of the scene and the parameters of the aquatic medium, leading to geometrically consistent depth maps, the elimination of water-column floaters, and photorealistic novel-view synthesis.

---

## The Evolution of Underwater Image Formation Models

Early underwater computer vision heavily relied on the Jaffe-McGlamery model or standard atmospheric dehazing equations (such as the Koschmieder model). The Jaffe-McGlamery model decomposes the light received by the camera into a direct reflection component, a forward-scatter component, and a backscatter component. However, these traditional models, as well as those derived from atmospheric fog removal, incorrectly assume that light attenuation is a weak function of wavelength.

In reality, the attenuation of light underwater is highly dependent on its wavelength; red light attenuates the fastest, often disappearing entirely at depths of five meters, while blue and green light penetrate much deeper. SeaSplat incorporates the revised Akkaynak-Treibitz underwater image formation model, which explicitly accounts for this differential attenuation of light across the color spectrum and separates the attenuation coefficient of the direct signal from the backscatter coefficient.

The Akkaynak-Treibitz model dictates that the observed image intensity $I_c$ for a given color channel $c \in \{R, G, B\}$ is a combination of the direct attenuated signal and the backscattered veiling light:


$$I_c = J_c \cdot e^{-\beta_D^c Z} + B_\infty^c \cdot (1 - e^{-\beta_B^c Z})$$

In this formulation, $J_c$ represents the true underlying radiance of the scene (the color if the water were miraculously removed), $Z$ is the distance from the camera to the object, $\beta_D^c$ is the channel-specific attenuation coefficient, $\beta_B^c$ is the backscatter coefficient, and $B_\infty^c$ represents the ambient backscatter water color at infinity.

---

## SeaSplat Optimization and Loss Functions

SeaSplat integrates this physical model directly into the differentiable rendering pipeline of 3D Gaussian Splatting. For a given camera viewpoint, the system renders an underlying true-color image $\hat{J}$ and a depth map $\hat{Z}$ derived from the z-coordinates of the 3D Gaussian representation. It then applies the learned, channel-specific attenuation and backscatter parameters to compute a reconstructed underwater image $\hat{I}$.

Because the optimization process is highly under-constrained—the model could theoretically assume zero backscatter and zero attenuation to satisfy a basic photometric loss—SeaSplat employs a highly specialized, composite loss function to guide the convergence toward physically plausible solutions:

* **Photometric Loss ($\mathcal{L}_{GS}$):** The standard combination of $L_1$ and D-SSIM loss between the rendered in-medium image $\hat{I}$ and the ground truth captured image $I$, ensuring the final rendered output matches the sensor data.


* **Backscatter Loss ($\mathcal{L}_{bs}$):** An adaptation of the dark channel prior originally developed for haze removal, applied to the direct signal $\hat{D} = I - \hat{B}$. This enforces physical constraints on the removed veiling light, prioritizing the recovery of contrast in heavily scattered regions.


* **Gray World and Saturation Losses ($\mathcal{L}_{gw}, \mathcal{L}_{sat}$):** Penalties that encourage the recovered true color $J$ to center around a neutral gray, counteracting the severe color imbalances typical of underwater imagery. The saturation loss prevents the optimization from pushing the restored colors into artificial, oversaturated extremes.


* **Depth-Weighted Reconstruction Loss ($\mathcal{L}_{Z-recon}$):** Emphasizes the recovery of details at greater distances from the camera, where the effects of attenuation and backscatter are most severe, ensuring the background is accurately modeled.


* **Depth Smoothness ($\mathcal{L}_{Zsmooth}$):** An edge-aware total variation loss that regularizes the depth map. It forces the depth estimates to remain smooth across continuous surfaces while allowing for sharp depth discontinuities at object boundaries (areas of high gradient in the original image).


* **Opacity Regularization ($\mathcal{L}_{op}$):** Specifically targets the "floater" problem by penalizing high opacity in pixels whose color closely matches the background water color $B_\infty$. This forces the network to represent the water column through the physical formation model rather than by placing geometric primitives in empty space.



By interleaving the optimization of the global medium parameters ($\beta_D$, $\beta_B$, $B_\infty$) with the standard Gaussian position and covariance updates, SeaSplat forces the 3D Gaussians to represent the true, restored color of the environment.

---

## Quantitative Performance and Comparative Analysis

The integration of the Akkaynak-Treibitz model directly into the rasterization pipeline yields significant improvements over baseline methods. SeaSplat was evaluated against the original 3DGS implementation and SeaThru-NeRF across multiple distinct geographic datasets (Curacao, Japanese Gardens in the Red Sea, Panama in the Pacific, and the IUI3 dataset). The framework consistently demonstrated superior performance in novel-view synthesis of the in-medium imagery.

| Dataset | Metric | 3DGS (Baseline) | SeaThru-NeRF | SeaSplat (Proposed) |
| --- | --- | --- | --- | --- |
| **Curacao** | PSNR $\uparrow$ | 28.01| 30.08| 30.30|
|  | SSIM $\uparrow$ | 0.88| 0.87| 0.90|
|  | LPIPS $\downarrow$ | 0.21| 0.27| 0.19|
| **Japanese Gardens** | PSNR $\uparrow$ | 21.47| 21.74| 22.70|
|  | SSIM $\uparrow$ | 0.85| 0.77| 0.87|
|  |LPIPS $\downarrow$ | 0.22| 0.29| 0.18||
| **Panama** | PSNR $\uparrow$ | 29.64| 27.69| 28.76|
| | SSIM $\uparrow$   | 0.90| 0.83| 0.90|
| | LPIPS $\downarrow$ | 0.17| 0.28| 0.15|

While the photometric metrics (PSNR, SSIM, LPIPS) indicate high visual fidelity, the qualitative differences in the depth maps are particularly striking. Baseline 3DGS produces depth maps riddled with noise and sharp artifacts corresponding to floaters in the water column. SeaThru-NeRF produces smoother depth maps but exhibits periodic artifacts and requires over 21 hours to train on a standard GPU. SeaSplat achieves coherent, smooth depth maps while maintaining a training time of approximately 1 hour and 25 minutes, with rendering speeds of 0.012 seconds per frame (roughly 80 FPS).

---

## Alternative and Advanced Underwater 3DGS Architectures

While SeaSplat represents a significant advancement in static underwater scene reconstruction, the unique challenges of aquatic environments have spurred a rapid diversification of specialized 3DGS frameworks. Researchers have expanded upon the foundational physics to address dynamic lighting, extreme degradation, and multi-sensor fusion.

### Spatiotemporal Degradation and Dynamic Lighting

Underwater environments are inherently dynamic. Surface waves refract sunlight, creating rapidly shifting caustic patterns on the seafloor, while the movement of the water itself causes temporal flickering. Models assuming static illumination struggle to converge accurately under these conditions.

MarineSTD-GS addresses this by explicitly modeling both spatial and temporal degradations. It introduces a dual-Gaussian design, pairing "Intrinsic Gaussians" (which represent the true, static scene geometry and appearance) with "Degraded Gaussians" (which render the degraded, time-varying observations). A Spatiotemporal Degradation Modeling (SDM) module predicts transient illumination perturbations caused by caustics and flickering, disentangling realistic scene representations from degraded videos through self-supervised learning.

Recurrent Gaussian Splatting (RecGS) takes an alternative approach to caustic removal. Rather than relying heavily on dual-primitive architectures, RecGS utilizes a recurrent feedback loop based on frequency analysis. It alternates between rendering the scene and extracting low-frequency caustic artifacts via Fast Fourier Transform (FFT) filtering. By minimizing photometric residuals iteratively, RecGS progressively removes illumination inconsistencies without relying on supervised annotated data, yielding photorealistic, artifact-free reconstructions of the seafloor.

### Unified Restoration Frameworks

In scenarios where the physical parameters of the water column are too complex for a generalized equation, some frameworks bridge the gap between deep learning-based Underwater Image Restoration (UIR) and geometric reconstruction.

R-Splatting integrates multiple enhanced views produced by diverse UIR models into a single reconstruction pipeline. It employs a lightweight illumination generator to sample latent codes, supporting diverse yet coherent renderings. To prevent the opacity optimization from overfitting to noisy or view-specific artifacts (a common issue in turbid water), R-Splatting introduces Uncertainty-Aware Opacity Optimization (UAOO), which models opacity as a stochastic function, suppressing abrupt gradient responses triggered by severe illumination variations.

Similarly, WaterSplatting represents the water medium as an additional volumetric field rather than predicting global attenuation maps, allowing the system to handle highly inhomogeneous environments where the optical properties of the water vary significantly across the scene.

### Acoustic-Optical Sensor Fusion

In highly turbid environments, such as estuarine waters or silty coastal areas, optical visibility can drop to mere centimeters. This necessitates the integration of acoustic sensors, specifically Forward-Looking Sonar (FLS), to complement optical data. Sonar imaging relies on acoustic pulses and measures the intensity of returning echoes binned by range and azimuth, offering superior penetration but lacking direct elevation data.

SonarReg-GS SLAM utilizes filtered FLS returns as sparse metric anchors. Through object-aware sampling and bearing-to-beam gating, acoustic returns are converted into dense metric depth priors. These priors regularize the scale of monocular depth estimation, preventing the scale-drift typically associated with purely optical underwater SLAM systems.

Aqua-Splat and SonarSplat take a more fundamental approach by extending the differentiable rasterizer itself to simulate acoustic image formation. The 3D Gaussians are endowed with acoustic reflectance and saturation properties. The rasterizer projects these Gaussians into range-azimuth space, accumulating acoustic intensity while accounting for acoustic wave propagation and phenomena such as azimuth streaking. This dual-modality optimization ensures that the underlying geometry aligns with both the optical and acoustic observations, yielding substantially lower Chamfer Distances in geometric reconstruction. Furthermore, NAS-GS (Noise-Aware Sonar Gaussian Splatting) incorporates a Gaussian Mixture Model (GMM) to capture complex sonar noise patterns, including side-lobes, speckle, and multi-path noise, preventing the 3D Gaussians from overfitting to acoustic artifacts.

| Framework | Core Innovation | Target Degradation | Primary Modality |
| --- | --- | --- | --- |
| **SeaSplat** | Akkaynak-Treibitz integration| Color shift, backscatter| Optical |
| **MarineSTD-GS** | Dual Intrinsic/Degraded Gaussians | Caustics, temporal flickering| Optical|
| **RecGS** | FFT-based recurrent filtering| Low-frequency caustics| Optical|
| **R-Splatting** | UIR integration, Stochastic Opacity | Inhomogeneous illumination| Optical|
| **Aqua-Splat** | Acoustic wave propagation modeling| High turbidity, zero visibility| Optical + Sonar|
| **NAS-GS** | Noise-aware GMM| Sonar speckle, side-lobes| Optical + Sonar|

---

## Real-World Application Context: The CUREE AUV and WHOI Research

The theoretical advancements in underwater 3DGS are inextricably linked to the hardware platforms used to acquire the necessary data. A prime example of this synergy is the Curious Underwater Robot for Ecosystem Exploration (CUREE), developed by the Woods Hole Oceanographic Institution (WHOI) Autonomous Robotics and Perception Laboratory (WARPLab) and MIT.

CUREE is a compact, highly transportable autonomous underwater vehicle designed to navigate complex coral reef ecosystems and intelligently sample its environment to estimate local biodiversity. The robot's primary sensing capabilities are derived from forward and downward-looking stereo camera pairs and a four-channel hydrophone array. This sensor suite is driven by an NVIDIA Jetson Orin NX module, which provides the edge AI computing power necessary to run fish detection neural networks and autonomous tracking algorithms in real-time.

The integration of 3DGS frameworks like SeaSplat with platforms like CUREE opens entirely new avenues for benthic ecology. Traditional methods for estimating reef structural complexity, such as the chain-and-tape rugosity index dating back to the 1970s, are limited to single linear profiles and predefined resolutions. By conducting low-altitude visual surveys, CUREE can capture dense, multi-view datasets of coral habitats. Processing these datasets through SeaSplat yields geometrically accurate, color-restored 3D models that allow marine biologists to calculate true volumetric rugosity and spatial heterogeneity at sub-meter resolutions, vastly improving the monitoring of coral reef health.

One of the foundational datasets utilized in the SeaSplat research was collected by CUREE in Salt Pond Bay, located in the US Virgin Islands. This dataset is unique as it features downward-facing imagery of the seafloor (a color chart) with the robot moving between low and high altitudes. Because the camera trajectory is purely vertical within the water column, standard 3DGS fails spectacularly, placing dense floaters throughout the depth of the water. SeaSplat, conversely, accurately learns a representation consisting solely of the seafloor, proving its capability to decouple the medium from the geometry in bounded, single-axis trajectories.

Beyond visual reconstruction, CUREE tackles the "cocktail party problem" of the ocean. The hydrophones collect spatial soundscape maps to identify bioactivity hotspots. However, isolating specific sounds—such as the vocalizations of targeted fish—is incredibly difficult due to the overwhelming background noise generated by snapping shrimp. By pairing advanced audio filtering with visual tracking initialized by transfer-learning models, CUREE can autonomously follow arbitrary animals, such as barracudas and stingrays, through highly complex midwater and benthic environments for extended periods.

---

## A Practitioner's Guide: Creating Datasets in Brighton, Australia

For practitioners seeking to leverage these advanced volumetric reconstruction techniques for testing and custom projects, acquiring high-quality data is the most critical hurdle. Capturing datasets in environments like Brighton, Australia, which sits on the shores of Port Phillip Bay, presents unique challenges distinct from tropical coral reefs.

### Contextualizing Port Phillip Bay

Port Phillip Bay is a shallow, largely enclosed marine environment. Unlike the crystal-clear waters of the Caribbean, the bay is subject to significant fluctuations in water visibility driven by tidal currents, nutrient-driven phytoplankton blooms, and the resuspension of fine sediments. Average Secchi disc transparency depths in similar bay areas can be as low as 1.5 meters, compared to over 5 meters in more exposed regions. This high turbidity means that light attenuation is severe, and backscatter from suspended particulate matter will quickly dominate any imagery if careful optical protocols are not followed.

### Underwater Optical Hardware: The Necessity of Dome Ports

The physical interface between the camera housing and the aquatic medium dictates the geometric validity of the captured dataset. When light passes from water, through a glass or acrylic port, and into the air inside the camera housing, it undergoes refraction as described by Snell’s Law.

Using a flat port for underwater photogrammetry or 3DGS is highly discouraged. Flat ports cause light rays entering at oblique angles to bend significantly, reducing the field of view (FOV) by approximately 25% and creating a magnification effect. More critically, flat ports introduce radial (pincushion) distortion and severe chromatic aberration (color fringing) at the edges of the image because different wavelengths of light refract at slightly different angles. Light rays striking the flat port at very shallow angles (beyond the critical angle) suffer total internal reflection, severely limiting the usability of wide-angle lenses. Because standard Structure-from-Motion (SfM) pipelines like COLMAP assume a single center of projection (the pinhole camera model), the complex refraction of a flat port degrades reconstruction accuracy. While specialized software like Refractive COLMAP exists to model this specific water-glass-air interface analytically, it significantly complicates the pipeline.

Therefore, dome ports are strictly recommended. A dome port is a hemispherical window designed so that the optical center of the camera lens aligns precisely with the center of curvature of the dome. When properly aligned, incoming light rays strike the glass perpendicularly and pass through unrefracted. This alignment preserves the true in-air FOV of the lens and eliminates the chromatic aberration and radial distortion associated with flat ports. However, the optics of a dome port create a "virtual image" located only a few inches in front of the lens. The camera must be equipped with a lens capable of focusing on this very close virtual image, rather than the actual physical distance to the subject. Using a dome port allows the standard OPENCV or PINHOLE camera models within COLMAP to function correctly, streamlining the dataset creation process.

### Camera Settings and Capture Strategies

Given the turbidity of Brighton's waters, the capture strategy must prioritize signal-to-noise ratio and geometric overlap.

* **Proximity to Subject:** Because suspended particles induce severe backscatter and rapid attenuation, the camera must remain as close to the target as physically possible. This necessitates the use of an ultra-wide rectilinear lens behind a properly calibrated, large-diameter dome port (typically 8 or 9 inches for rectilinear wide-angle lenses).


* **Lighting Strategies:** Natural ambient lighting is preferable for 3DGS to avoid view-dependent lighting inconsistencies across different camera poses. However, in murky waters, ambient light may be insufficient. If artificial strobes or continuous video lights are utilized, they must be mounted on long arms and angled outward. This cross-lighting technique minimizes the direct illumination of suspended particles directly between the lens and the subject, which would otherwise result in disastrous backscatter.


* **Camera Settings:** To counteract low light and subject motion (whether from the diver/ROV or ocean currents), the camera's ISO should be pushed higher (e.g., 1600-6400). Shutter speed must be maintained at a minimum of 1/125s to eliminate motion blur, which destroys the high-frequency details required for feature extraction. The aperture should be maintained between f/5.6 and f/8 to ensure a deep enough depth of field to keep the entire subject in focus. Images must be captured in RAW format to allow for pre-processing white balance adjustments if utilizing frameworks that require color correction prior to training.


* **Dataset Overlap:** Turbidity obscures distant features, meaning the SfM algorithm will rely heavily on localized texture. The operator must capture images with a minimum of 70% to 80% overlap between consecutive frames, moving slowly and steadily in a grid or orbital pattern to ensure multi-view consistency.


* **Scale Calibration:** To ensure the final 3D model accurately reflects real-world dimensions (crucial for ecological surveys or engineering assessments), physical scale bars of known length should be placed in the scene prior to capture. These can later be used in COLMAP's `model_aligner` tool to scale-constrain the photogrammetric model to real-world meters.



---

## Computational Infrastructure and Training Pipeline

Training explicit 3D Gaussian Splatting models, and particularly physics-constrained variants like SeaSplat, is highly demanding on GPU hardware. While the optimization converges quickly compared to NeRFs, the explicit storage of millions of Gaussians—alongside their gradients and Adam optimizer states—requires massive amounts of Video RAM (VRAM).

For practitioners in Australia without access to local high-end workstations (e.g., NVIDIA RTX 3090 or 4090 with 24GB VRAM), cloud GPU rental is a practical necessity. Providers such as OVHcloud operate data centers in Sydney and Melbourne, offering instances equipped with NVIDIA A100 or RTX 4090 GPUs. Utilizing a geographically local data center is advantageous, as uploading large photogrammetry datasets (often tens of gigabytes of raw RAW/JPEG images) to overseas servers introduces severe latency bottlenecks. An A100 GPU, with its high VRAM capacity and 2-3 TB/s memory bandwidth, is ideal for keeping the densification and rendering steps fed during training.

### Structure-from-Motion Processing via COLMAP

Once the dataset is securely transferred, the images must be processed to extract sparse geometry and camera poses. The 3DGS architecture relies strictly on the directory structure and output formats generated by COLMAP. The dataset must be organized into a root directory containing an `images/` folder with the undistorted captures.

The preprocessing pipeline utilizes the `convert.py` script provided in the standard 3DGS repository. This script automates the entire COLMAP pipeline: feature extraction, feature matching, sparse bundle adjustment, and image undistortion.

An execution command for a local dataset is formatted as follows:

```bash
python convert.py -s /path/to/dataset --camera OPENCV

```

Specifying the OPENCV camera model is essential for datasets captured with dome ports, as it accurately accounts for the radial and tangential lens distortions inherent in ultra-wide lenses prior to the undistortion step. If the dataset comprises sequential video frames (e.g., extracted via FFmpeg), the feature matching phase can be vastly accelerated by appending `--match sequential` to the command. Upon successful completion, `convert.py` generates a `sparse/0/` directory containing `cameras.bin`, `images.bin`, and `points3D.bin`. The `points3D.bin` file provides the foundational sparse point cloud that 3DGS utilizes to initialize the Gaussian means.

### SeaSplat Execution and Docker Environments

For seamless deployment on cloud instances, utilizing a Docker container is highly recommended to circumvent CUDA dependency conflicts. 3DGS relies on custom CUDA kernels (specifically the `diff-gaussian-rasterization` submodule), which must be compiled against the exact CUDA architecture of the host GPU. The SeaSplat repository provides a Dockerfile configured for CUDA 11.8.

The container is built and executed with hardware passthrough:

```bash
docker build --tag seasplat --build-arg USER_ID=$(id -u) -f Dockerfile .
docker run -u $(id -u) --gpus '"device=0"' -v ~/.cache/:/home/user/.cache/ -v ~/localdata:/home/user/localdata --rm -it --shm-size=64gb seasplat:latest

```

With the environment configured, the SeaSplat training process is initiated. The SeaSplat architecture inherits the standard hyperparameter structure of the original Inria codebase while introducing specific flags for underwater physics. The training script is invoked as follows:

```bash
python train.py -s /path/to/dataset --exp experiment_name --do_seathru --seathru_from_iter 10000

```

The `--do_seathru` flag activates the Spatiotemporal Degradation Modeling module and the integration of the Akkaynak-Treibitz equations. The `--seathru_from_iter 10000` parameter acts as a critical scheduling heuristic. During the first 10,000 iterations, the model trains purely as a standard 3DGS representation, prioritizing the initialization of broad scene geometry and camera alignment based on the degraded imagery. Once this geometric foundation is established, the physics-based image formation model engages, allowing the system to disentangle the true scene color from the volumetric attenuation and backscatter without destabilizing the spatial layout.

### Advanced Hyperparameter Tuning

For datasets captured in turbid environments like Brighton, standard hyperparameters may fail to converge optimally. Practitioners can manipulate specific command-line arguments to guide the densification process:

| Argument | Default | Function and Optimization Strategy |
| --- | --- | --- |
| `--iterations` | 30_000 | Total training steps. Can be extended for complex scenes to allow fine details to settle after the densification phase concludes at 15,000 iterations.|
| `--densify_grad_threshold` | 0.0002 | The positional gradient magnitude required to trigger Gaussian cloning or splitting. Increasing this value (e.g., to 0.0004) prevents the model from generating excessive floaters in response to the optical noise present in turbid water.|
| `--sh_degree` | 3 | Defines the complexity of the view-dependent color representation. For murky underwater scenes lacking specular highlights, reducing this to 1 or 2 significantly decreases VRAM usage and file size without sacrificing perceptual quality.|
| `--data_device` | cuda | Determines where source image tensors are stored. If GPU VRAM is exhausted by the image load, switching to cpu slows down training but allows the processing of significantly larger, high-resolution datasets.|

---

## The Role of Optimized Backends: gsplat and Nerfstudio

While SeaSplat is built on the original Inria CUDA rasterizer, the broader 3DGS ecosystem has rapidly evolved to address efficiency bottlenecks. For users seeking faster training times and lower memory footprints (or attempting to adapt SeaSplat methodologies to newer architectures), the `gsplat` library has emerged as an industry standard.

Developed by the Nerfstudio project, `gsplat` is a highly optimized, open-source library that provides a more memory-efficient CUDA implementation of the rasterizer. Crucially, it supports multi-GPU Distributed Data Parallel (DDP) training, allowing massive scenes exceeding 10 million Gaussians to be partitioned across multiple compute nodes. By integrating 3DGS into the Nerfstudio ecosystem (via the `splatfacto` method), users also gain access to Viser, a powerful web-based viewer that enables real-time monitoring of the optimization process directly through a browser, facilitating immediate feedback on hyperparameter adjustments.

---

## Post-Processing, Compression, and Web Deployment

Following a successful 30,000-iteration training run, the output is a `.ply` file containing the explicit parameters (position, covariance, opacity, and SH coefficients) of every Gaussian in the scene. For a typical scene, this file can easily exceed several hundred megabytes, making it highly impractical for web distribution, archival storage, or interactive client-side rendering.

To bridge the gap between high-fidelity local rendering and seamless web accessibility, aggressive compression pipelines have been developed. Foremost among these are the `splat-transform` command-line utility and the SuperSplat web editor, developed by the PlayCanvas team.

### Compression Algorithms and the SOG Format

An uncompressed 3DGS `.ply` file stores 232 bytes per splat, heavily burdened by the 48 floating-point values dedicated to the higher-order Spherical Harmonics. To facilitate web streaming, the PlayCanvas ecosystem introduced the Spatially Ordered Gaussians (SOG) format.

The SOG compression algorithm achieves up to a 15x reduction in file size through a combination of spatial chunking, quantization, and texture packing:

* **Chunking and Spatial Sorting:** The scene is divided into discrete chunks of 256 spatially localized Gaussians.


* **Quantization:** Instead of storing absolute 32-bit floating-point coordinates, the algorithm calculates the bounding box (min/max extents) for each chunk. The positions and scales of the individual Gaussians within that chunk are then normalized and quantized into highly compressed lower-precision integers relative to the chunk boundaries.


* **Texture Packing:** The SOG format can externalize the color and opacity data into highly compressed, lossless `.webp` images, leaving a lightweight `meta.json` file to dictate the spatial layout.



### Pipeline Execution with splat-transform

The `splat-transform` utility, built on Node.js, allows developers to automate these compression and filtering tasks. A practitioner can filter out low-opacity "floater" Gaussians, strip unnecessary higher-order SH bands, and convert a heavy `.ply` into a web-ready `.sog` file in a single command line operation:

```bash
splat-transform input.ply --filterNaN -c opacity,gt,0.1 --filterBands 0 output.sog

```

Furthermore, the tool facilitates the generation of Level of Detail (LOD) hierarchies. By producing a `lod-meta.json` file, a web renderer can intelligently stream high-density chunks only when the user's virtual camera approaches those specific spatial coordinates, ensuring consistent 60 FPS performance on mobile devices and low-end hardware. The CLI also supports exporting the Gaussian data to CSV format, enabling marine biologists to run statistical analyses on the geometric properties of the scene using standard spreadsheet software.

---

## Scene Editing and Visualization: SuperSplat

For visual editing prior to deployment, the raw `.ply` or compressed `.sog` files can be imported into SuperSplat, an open-source, engine-agnostic browser application. SuperSplat provides a spatial bounding-box gizmo that allows users to manually select and delete errant Gaussians—such as artifacts generated by moving fish, suspended particulate matter that the SeaSplat optimization failed to prune, or poorly reconstructed background elements.

| SuperSplat Operation | Purpose | Typical Use Case |
| --- | --- | --- |
| **Crop / Trim** | Removes unnecessary areas of a splat| Shorten loading times, focus on the main subject (e.g., a specific coral head), remove empty regions|
| **Merge / Combine** | Combines multiple splats into one| Simplify render pipelines, build expansive scenes from smaller captures|
| **Floater Cleaning** | Removes floating/unconnected splats| Cleaning scan artifacts and optical noise inherent in turbid underwater captures|
| **Insert Volume** | Defines a bounding box to isolate edits| Editing only a specific part of a splat without affecting the surrounding geometry|

Once the scene has been trimmed and optimized, SuperSplat allows the user to publish the splat directly to a hosted URL. This provides an `<iframe>` embed code that can be integrated into custom HTML frontends, digital portfolios, or interactive ecological reports, democratizing access to high-fidelity volumetric marine data.

---

## Conclusion

The transition from volumetric ray-marching to explicit 3D Gaussian Splatting represents a watershed moment in computational photography and scene reconstruction. By combining the differentiability required for neural optimization with the extreme efficiency of hardware-accelerated rasterization, 3DGS has fundamentally lowered the barrier to entry for volumetric capture.

In the highly specialized domain of underwater imaging, frameworks like SeaSplat demonstrate that these explicit geometric representations can be seamlessly constrained by fundamental physical optics. By disentangling the radiometric degradation of the water column from the underlying benthic structure using the Akkaynak-Treibitz model, researchers can achieve accurate color restoration and robust depth estimation even in challenging marine environments. As advanced variants introduce spatiotemporal degradation modeling and acoustic-optical sensor fusion, the capability to reconstruct zero-visibility environments continues to expand.

For practitioners establishing field pipelines in regions like Brighton, Australia, success hinges on a holistic understanding of the entire data lifecycle. From the physical selection of dome ports to mitigate Snell's Law refractions and the rigorous execution of high-overlap, well-lit photogrammetry patterns, to the cloud-based execution of customized COLMAP and Docker containers, every step must be optimized for the aquatic medium. Furthermore, leveraging the aggressive quantization techniques employed by tools like `splat-transform` and SuperSplat ensures that the resulting data can be effectively disseminated. As these technologies mature, the capacity to rapidly map, analyze, and share interactive 3D digital twins of underwater ecosystems will become a foundational capability in marine biology, underwater robotics, and environmental conservation.