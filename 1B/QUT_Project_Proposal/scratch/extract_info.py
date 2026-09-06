import os
import subprocess
import re

pdfs = {
    "GS-DIFF (18)": "18-scenechange0.pdf",
    "3DGS-CD (20)": "20-scenechange2.pdf",
    "Zhou et al. (17)": "17-scenechange1.pdf",
    "Zhong et al. (19)": "19.pdf",
    
    "SeaSplat (11)": "11-SeaSplat_Representing_Underwater_Scenes_with_3D_Gaussian_Splatting_and_a_Physically_Grounded_Image_Formation_Model.pdf",
    "WaterGS (29)": "29-WaterGS.pdf",
    "DualPhys-GS (27)": "27-1-s2.0-S0097849325002468-main.pdf",
    "UW-3DGS (26)": "26-2508.06169v1.pdf",
    "RecGS (7)": "7.pdf",
    "WaterClear-GS (24)": "24-2601.19753v1.pdf",
    "Water-Adapted 3DGS (10)": "10.pdf",
    "RUSplatting (25)": "25-2505.15737v2.pdf",
    "UW-GS (30)": "30-UW-GS_Distractor-Aware_3D_Gaussian_Splatting_for_Enhanced_Underwater_Scene_Reconstruction.pdf",
    "Spatiotemporal 3DGS (8)": "8.pdf",
    "Underwater360 (31)": "31-2605.26447v1.pdf",
    "SonarSplat (3)": "3-SonarSplat_Novel_View_Synthesis_of_Imaging_Sonar_via_Gaussian_Splatting.pdf",
    "NAS-GS (1)": "1.pdf",
    "Aqua-Splat (4)": "4-Aqua-Splat_Physically-Informed_Sonar-Camera_Gaussian_Splatting_for_Underwater_3D_Reconstruction.pdf",
    "SonarReg-GS (2)": "2.pdf",
    
    "Fast Methods (5)": "5.pdf",
    "Fast Methods (6)": "6.pdf"
}

out_md = "scratch/summaries.md"
base_path = "/home/hecke/0Github/UMP/Literature"

with open(out_md, 'w') as f:
    for name, pdf in pdfs.items():
        pdf_path = os.path.join(base_path, pdf)
        if not os.path.exists(pdf_path):
            f.write(f"## {name}\nFile not found: {pdf_path}\n\n")
            continue
            
        try:
            text = subprocess.check_output(['pdftotext', pdf_path, '-']).decode('utf-8', errors='ignore')
            
            abstract = "Not found"
            m_abs = re.search(r'abstract(.*?)(introduction|1\.)', text, re.IGNORECASE | re.DOTALL)
            if m_abs:
                abstract = m_abs.group(1).strip()[:1000].replace('\n', ' ')
                
            conc = "Not found"
            m_conc = re.search(r'(conclusion|discussion)(.*?)(references|acknowledgment|acknowledgement)', text, re.IGNORECASE | re.DOTALL)
            if m_conc:
                conc = m_conc.group(2).strip()[:1500].replace('\n', ' ')
                
            f.write(f"## {name}\n")
            f.write(f"**Abstract:** {abstract}\n\n")
            f.write(f"**Conclusion/Discussion:** {conc}\n\n")
            
        except Exception as e:
            f.write(f"## {name}\nError: {str(e)}\n\n")

print("Done")
