# Documentation Overview & AI Directives

This file is the entry point for the project's documentation. It contains a dynamically updated index and the core rules for the AI agent responsible for maintaining it.

## 1. Core Purpose

The `agentdocs/` directory is the "living brain" of this project. It is maintained primarily by AI agents to provide context for future development and to serve as a reference for human developers.

## 2. AI Agent Rules of Engagement

As an AI agent, you must adhere to the following rules when managing this documentation.

### Rule 1: Start Here, Always
Always read this file (`agentdocs/README.md`) first to understand your directives before reading or modifying any other file.

### Rule 2: Update Before Creating
When documenting new features, learnings, or code changes, first search the existing files (listed in the index below) for a suitable place to add the information. The goal is to keep information consolidated and contextual.

### Rule 3: Create New Files When Necessary
Create a new, descriptively-named `.md` file only if the information represents a new, distinct concept (e.g., `authentication_flow.md`, `database_schema.md`) that does not fit naturally into any existing document.

After creating a new file, you **must** immediately update the index in this `README.md` with a link to the new file and a one-sentence description.

### Rule 4: Refactor Documentation Aggressively
- **Split:** If a file grows too long (e.g., over 500 lines) and covers multiple distinct sub-topics, split it into more focused files.
- **Merge:** If multiple small files cover very similar topics, merge them into a single, more comprehensive file.
- **Organize:** Consider creating sub-folders (e.g., `agentdocs/api/`, `agentdocs/ui/`) to group related files if a topic becomes complex with many documents.
- **Update Index:** Always update the index below after any refactoring.

### Rule 5: Prioritize and Be Concise
- **Mark Importance:** Use `**[CRITICAL]**` to flag information essential for the project's function (e.g., security vulnerabilities, core architectural constraints). Use `**[KEY-CONCEPT]**` for important patterns or decisions.
- **Remove Redundancy:** Eliminate superfluous information and summarize where possible, but never at the expense of critical details.

---

## 3. Documentation Index

*This index is managed by the AI agent and should always be up-to-date.*

- [**Repository Master Guide & Model Outputs Evaluation Suite**](../README.md): Unified root manual covering the 5-phase operational lifecycle (Setup -> Run -> Extract -> Organise -> Review), the `Model_Outputs/` evaluation workspace, per-model SuGaR `.obj` mesh review in Blender/MeshLab, custom dataset ingestion guidelines, and the temporal underwater OSCD research roadmap.
- [**Agent Instructions**](./AGENT_INSTRUCTIONS.md): Central instructions for AI agents working in this repo.
- [**Project Overview**](./overview.md): A high-level summary of the project's purpose and goals.
- [**Pipeline & Automation Scripts**](./pipeline_and_scripts.md): Technical documentation for the one-shot bash automation suite, Conda environments, execution stages, and diagnostic tools.
- [**Change Log**](./change_log.md): Chronological timeline of significant project updates, architecture changes, and file movements.
- [**HPC Guide**](./HPC_Guide.md): Master reference for cluster operations, PBS job submission, GPU requests, and Conda management on the QUT Aqua cluster.
- [**Attempt 5 Failure Analysis**](./attempt_5_failure_analysis.md): Comprehensive forensic audit and root-cause diagnostic of all 15 failed executions in Attempt 5, with exact code-level fixes for Attempt 6.
- [**Attempt 6 Failure Analysis**](./attempt_6_failure_analysis.md): Comprehensive forensic audit, verification of the 6 full-lifecycle successful runs, root-cause diagnostics of all 9 failed runs in Attempt 6, and exact code-level blueprint for Attempt 7.
- [**Attempt 7 Failure Analysis**](./attempt_7_failure_analysis.md): Comprehensive forensic audit, verification of the 10 full-lifecycle successful runs, root-cause diagnostics of the 5 failed runs in Attempt 7, and exact code-level blueprint for Attempt 8.
- [**Attempt 8 Failure Analysis**](./attempt_8_failure_analysis.md): Comprehensive forensic audit, verification of the 14 full-lifecycle successful runs, root-cause diagnostics of the single failed run in Attempt 8, PBS log synchronization investigation, and exact code-level blueprint for Attempt 9.
- [**Attempt 9 Failure Analysis**](./attempt_9_failure_analysis.md): Forensic root-cause diagnostic of the Attempt 9 `oscd` failure (`RuntimeError: selected index k out of range` at `poses/ransac.py:182` caused by COLMAP `distorted/sparse/0` 2-image fragment selection + `scene/keyframe.py:138` unconditional early-return bug) and full end-to-end audit of `update.py`, Stage 5 SuGaR mesh extraction, Stage 6 `utils/metrics.py` `sys.path`, and `CONDA_DIR` resolution.
- [**Attempt 10 Verification Report**](./attempt_10_verification.md): Final verification and master completion report for Attempt 10, confirming 100% full-lifecycle execution of `oscd` (SSIM 0.8315, PSNR 27.08 dB, SuGaR mesh export) and the historic 15 / 15 (100%) success milestone across the entire benchmark suite.
