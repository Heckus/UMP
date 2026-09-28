import re
with open('Codebase/3DGS-Change-Detection/O-SCD-main/utils/evaluate.py', 'r') as f:
    content = f.read()

old_print = '''    if miou_scores:
        mean_miou = torch.tensor(miou_scores).mean().item()
        mean_f1 = torch.tensor(f1_scores).mean().item()

        print(f"Mean IoU: {mean_miou}")
        print(f"Mean F1: {mean_f1}")

    return mean_miou, mean_f1'''

new_print = '''    if miou_scores:
        mean_miou = torch.tensor(miou_scores).mean().item()
        mean_f1 = torch.tensor(f1_scores).mean().item()

        print(f"Mean IoU: {mean_miou}")
        print(f"Mean F1: {mean_f1}")
        
        # Save to evaluation.json
        import json
        out_path = os.path.join(os.path.dirname(os.path.dirname(predicted_binary_dir)), "evaluation.json")
        with open(out_path, 'w') as f:
            json.dump({"Mean IoU": mean_miou, "Mean F1": mean_f1}, f, indent=4)

    return mean_miou, mean_f1'''

content = content.replace(old_print, new_print)

with open('Codebase/3DGS-Change-Detection/O-SCD-main/utils/evaluate.py', 'w') as f:
    f.write(content)
