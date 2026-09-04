import os

chapters_dir = '/home/hecke/0Github/UMP/1B/QUT_Project_Proposal/Chapters'
os.makedirs(chapters_dir, exist_ok=True)

chapters = {
    '1_General Objective.tex': r"""
This project aims to address a critical gap in multi-view Scene Change Detection (SCD) for underwater environments by investigating and developing primitive-space change detection methods within underwater 3D Gaussian Splatting (3DGS) models. 

The primary objective is to move beyond traditional render-then-compare paradigms (which rely on pixel-space comparison) by performing change detection directly on the 3DGS primitives. By analyzing native primitive attributes—position, anisotropic covariance, and color—this project will evaluate whether these attributes carry sufficient signal for reliable scene change detection. 

The research will investigate algorithms to handle the inherent challenges of independent 3DGS reconstructions, specifically geometric drift (representation ambiguity and observation uncertainty) and photometric drift. Ultimately, the project will apply this methodology to the EcoRRAP dataset provided by the Australian Institute of Marine Science (AIMS) and the QUT Centre for Robotics, testing its ability to separate structural changes (e.g., coral growth or breakage) from surface-level appearance changes (e.g., bleaching or lighting shifts) in a complex, real-world underwater environment.
""",
    '2_Literature Review.tex': r"""
\section{Introduction}
Underwater 3D scene reconstruction and change detection are critical for marine monitoring, such as tracking coral reef health and adaptation. While 3D Gaussian Splatting (3DGS) has emerged as an efficient and photorealistic representation for digital twins, its application in underwater environments remains challenging due to the complex physical properties of water, including light scattering, attenuation, and dynamic elements. This review categorizes recent advancements in underwater 3DGS and scene change detection into five key groups based on their technical approach to solving the underwater degradation problem.

\section{Physical Image Formation \& Inverse Rendering Models}
These methods strictly embed the physics of light, such as the Jaffe-McGlamery model, into the rendering equation to separate scene geometry from water degradation (attenuation, scattering, backscatter). \textit{SeaSplat}~\cite{11128502} was the first to constrain 3DGS using a physically grounded range- and color-dependent model. \textit{WaterGS}~\cite{WaterGS} framed the reconstruction as a formal inverse rendering problem using 2D Gaussians and bundle adjustment. \textit{DualPhys-GS}~\cite{DualPhysGS} uses a dual feature-guided scattering-attenuation model, while \textit{UW-3DGS}~\cite{UW3DGS} employs a learnable image-formation module and Physics-Aware Uncertainty Pruning (PAUP) to filter noise. These methods achieve true "clear water" novel view synthesis by mathematically stripping away the medium.

\section{Image Restoration (UIR) \& Multi-View Priors}
Instead of directly modeling physics during rendering, these methods bridge traditional 2D underwater image enhancement with 3D structural consistency. \textit{R-Splatting}~\cite{RSplatting} leverages pre-enhanced views from diverse 2D restoration models and introduces an illumination generator. \textit{WaterClear-GS}~\cite{WaterClearGS} employs dual-branch optimization to maintain structural photometric consistency while cleaning the textures. This approach trades the complexity of physical modeling for the robustness of 2D pre-processing neural networks.

\section{Geometric \& Scale Adaptations for Turbidity}
These papers focus on altering the structural and rendering mechanics of the Gaussians to survive low-visibility, sparse data, or extreme depths. \textit{Water-Adapted 3DGS}~\cite{10.3389/fmars.2025.1573612} modifies the primitives themselves using complexity-adaptive distribution and depth-adaptive multi-scale radius rendering. \textit{RUSplatting}~\cite{RUSplatting} uses frame interpolation and decoupled RGB learning specifically to survive sparse-view, low-light deep-sea settings. \textit{AquaSplatting}~\cite{11184160} combines implicit and explicit representations to handle sparse far-field data in cloudy water. Modifying Gaussian primitives significantly improves geometric stability over standard 3DGS when dealing with highly turbid water.

\section{Dynamic Environments \& Transient Artifacts}
Underwater environments are rarely static. This group deals with time-varying visibility and moving objects like marine life, divers, or floating particles. \textit{UW-GS}~\cite{UWGS} uses distance-dependent variance and binary motion masks to filter out transient fish and divers. \textit{Spatiotemporal Degradation-Aware 3DGS}~\cite{Liu_2025} tracks changing water currents, localized turbidity spikes, and lighting variations over time, highlighting the shift from static scene reconstruction to handling the complex temporal dynamics of real-world ocean environments.

\section{Alternative Optics \& Benchmarking Studies}
Papers that expand capture mechanics or provide meta-analysis. \textit{Underwater360}~\cite{Underwater360} introduces omnidirectional spherical ray-casting to eliminate refraction distortions in wide-angle setups. \textit{Gaussian Splatting Underwater: A Controlled Cross-Regime Study}~\cite{CrossRegime} provides a rigorous benchmark evaluating system limitations across various turbidity scales. \textit{Gaussian Splashing}~\cite{GaussianSplashing} is an early foundational study adapting direct volumetric rendering explicitly to aquatic medium physics.

\section{Conclusion}
The literature demonstrates a clear trajectory from adapting basic 3DGS to underwater scenes via image restoration priors, to embedding complex physical models, and finally adapting the primitives themselves for robustness. The proposed primitive-space scene change detection pipeline will build upon these foundational works, leveraging the geometric and photometric properties of the primitives to separate structural changes from appearance changes and environmental drift.
""",
    '3_Stakeholders and Resources.tex': r"""
\section{Stakeholders}
The stakeholders for this project are identified in the table below. Regular updates will be provided to the supervisor, with final outcomes presented to the QUT engineering faculty.

\begin{table}[H]
\centering
\caption{Project Stakeholders}
\begin{tabularx}{\textwidth}{l X}
\toprule
\textbf{Stakeholder} & \textbf{Interest / Role} \\
\midrule
Project Supervisor & Niko Suenderhauf. Provides technical guidance, assesses progress, ensures academic rigour. \\
QUT Centre for Robotics & End-user of the SCD pipeline for robotics mapping and autonomy research. \\
AIMS (Australian Institute of Marine Science) & Provider of the EcoRRAP dataset; interested in tracking coral reef health and adaptation. \\
Future Students & Potential users of the GS-DIFF algorithm for advanced scene change detection and structural monitoring. \\
\bottomrule
\end{tabularx}
\end{table}

\section{Resources}
Successful completion of this project requires the following resources:
\begin{itemize}
    \item \textbf{Dataset:} The AIMS EcoRRAP dataset, containing 4D field photogrammetry of reef clusters, will serve as the testing foundation.
    \item \textbf{Computing Hardware:} Access to high-performance computing with dedicated GPUs (e.g., NVIDIA RTX 4090 or equivalent) for processing and rendering 3DGS models efficiently.
    \item \textbf{Software:} Agisoft Metashape for initial processing, Python for script development, and PyTorch for 3DGS optimizations.
\end{itemize}
""",
    '4_Project Methodology.tex': r"""
The project will follow a systems engineering approach, utilizing the AIMS EcoRRAP dataset to validate a newly proposed primitive-space change detection pipeline.

\section{Proposed Pipeline}
The methodology consists of several key stages:
\begin{enumerate}
    \item \textbf{Dataset Processing:} Using EcoRRAP imagery from two collection times (Time A and Time B).
    \item \textbf{Structure-from-Motion (SfM):} Running COLMAP on both datasets to estimate camera poses and sparse point clouds.
    \item \textbf{3DGS Reconstruction:} Utilizing algorithms like Aqua Splat or Water-Adapted 3DGS to generate high-fidelity, water-removed reconstructions of the reef at each time point.
    \item \textbf{Primitive-Space Comparison (GS-DIFF):} 
    \begin{itemize}
        \item Applying geometric drift modeling (covariance inflation and observation uncertainty).
        \item Computing geometric and appearance kernels directly on the primitives.
    \end{itemize}
    \item \textbf{Change Maps Generation:} Extracting explicit Colour Change Maps, Geometry Change Maps, and a combined Full Change Map.
\end{enumerate}
""",
    '5_Deliverables.tex': r"""
The key deliverables for this project are:
\begin{enumerate}
    \item A fully operational primitive-space scene change detection pipeline (GS-DIFF) tailored for underwater 3DGS.
    \item A set of generated change maps (Geometric, Colour, and Full) demonstrating the algorithm's performance on the EcoRRAP dataset.
    \item A comprehensive project report detailing the theoretical methodology, implementation, and evaluation results.
    \item A codebase repository containing the Python/PyTorch implementation and associated tools.
\end{enumerate}
""",
    '6_Quality and Sustainability.tex': r"""
\section{Quality}
The quality of the final deliverable will be validated against a set of performance criteria using standard scene change detection metrics:
\begin{itemize}
    \item \textbf{Accuracy Metrics:} Evaluating Mean Intersection over Union (mIoU) and F1 score against baseline render-then-compare methods.
    \item \textbf{Disambiguation:} The ability to successfully separate structural changes from surface-level color changes accurately.
    \item \textbf{Robustness:} Performance under the inherent underwater noise found in the EcoRRAP dataset.
\end{itemize}

\section{Sustainability}
Sustainability will be considered through:
\begin{itemize}
    \item \textbf{Code Efficiency:} Ensuring the primitive comparison runs efficiently without requiring heavy, power-intensive render-then-compare loops across hundreds of viewpoints.
    \item \textbf{Knowledge Transfer:} Producing comprehensive documentation and a well-commented codebase to ensure the project's findings can be built upon in future QUT Centre for Robotics research.
\end{itemize}
""",
    '7_Risks Requirements and Constraints.tex': r"""
\section{Constraints}
\begin{itemize}
    \item \textbf{Time:} The project spans over two semesters and must meet the scheduled progress checks.
    \item \textbf{Data Availability:} Dependence on the successful licensing and transfer of the EcoRRAP dataset from AIMS.
    \item \textbf{Computing Power:} Training 3DGS models is computationally expensive and is constrained by available GPU resources.
\end{itemize}

\section{Risks and Blockers}
\begin{itemize}
    \item \textbf{Extreme Environmental Change:} Too much change between timestamps could result in completely uncorrelated reconstructions, making tracking impossible.
    \item \textbf{Moving Features:} Transient features in the dataset like sea animals, sand, or shadows duplicating on the change map and cluttering the output.
    \item \textbf{Geometric Noise:} If water or geometric noise cannot be removed completely during the initial reconstruction phase, these errors will propagate into the GS-DIFF model.
    \item \textbf{Complexity of Coral:} Coral is highly geometrically complex and can be difficult to model accurately via Gaussian splatting while being measured under noise.
\end{itemize}
""",
    '8_Timeline and Deliverables.tex': r"""
The project is scheduled over two semesters, concluding in October 2027.

\begin{table}[H]
\centering
\caption{Project Timeline}
\begin{tabularx}{\textwidth}{l l X}
\toprule
\textbf{Phase} & \textbf{Due Date} & \textbf{Deliverable(s)} \\
\midrule
Phase 1: Planning & Week 7 & Project Proposal (this document). \\
Phase 2: Data \& Setup & Week 12 & EcoRRAP dataset secured, baseline COLMAP models generated. \\
Phase 3: Interim Review & October 2026 & Presentation of progress, initial 3DGS reconstruction tests, and primitive comparison mockups. \\
Phase 4: Algorithm Dev & Semester 1, 2027 & GS-DIFF pipeline integration with underwater specific adaptations. \\
Phase 5: Evaluation & Semester 2, 2027 & Extracting change maps and evaluating mIoU/F1 scores. \\
Phase 6: Final Reporting & October 2027 & Full results, Draft Final Report, Final Report, Oral Presentation. \\
\bottomrule
\end{tabularx}
\end{table}
""",
    '9_Management of Project Changes.tex': r"""
Any requested changes to the project scope by the supervisor or other stakeholders will be formally managed. A change request will be documented, outlining the nature of the change, its impact on the timeline and resources, and the reason for the change. This document will be reviewed with the supervisor before any new work is undertaken. This scope of work will be updated to reflect any approved changes, and version control will be maintained using Git.
""",
    '10_Sign off.tex': r"""
By signing below, the Student Engineer agrees to undertake the project as outlined in this Scope of Work.

\vspace{2cm}

\noindent\begin{tabular}{ll}
\makebox[2.5in]{\hrulefill} & \makebox[2.5in]{\hrulefill}\\
\textbf{STUDENT ENGINEER} & \textbf{DATE}\\[8ex]% adds space between the two sets of signatures
\end{tabular}
""",
    'Appendix_A_Risk Assessment.tex': r"""
The following document is the official QUT risk assessment for this project, covering computational laboratory work and data handling procedures. (To be appended).
"""
}

for filename, content in chapters.items():
    with open(os.path.join(chapters_dir, filename), 'w') as f:
        f.write(content.strip())
