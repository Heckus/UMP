#
# Copyright (C) 2025, Inria
# GRAPHDECO research group, https://team.inria.fr/graphdeco
# All rights reserved.
#
# This software is free for non-commercial, research and evaluation use 
# under the terms of the LICENSE.md file.
#
# For inquiries contact  george.drettakis@inria.fr
#

import torch
import torch.nn.functional as F
import os
import copy

from scene.extractor_model import *

class DenseExtractor():
    """Extract dense feature maps from an image."""
    @torch.no_grad()
    def __init__(self, width, height):
        cache_path = f"models/cache/dense_extractor_{width}_{height}.pt"
        dummy_img = torch.randn(1, 3, height, width).cuda().to(torch.half)
        
        if os.path.exists(cache_path):
            self.extractor = torch.jit.load(cache_path)
        else:
            repo_base = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
            local_xfeat_repo = os.path.join(repo_base, "submodules", "accelerated_features")
            local_weights = os.path.join(local_xfeat_repo, "weights", "xfeat.pt")
            if not os.path.exists(local_weights):
                local_weights = os.path.join(repo_base, "models", "weights", "xfeat.pt")
            
            if os.path.exists(local_xfeat_repo):
                import sys
                if local_xfeat_repo not in sys.path:
                    sys.path.insert(0, local_xfeat_repo)
                from modules.xfeat import XFeat
                weights_arg = local_weights if os.path.exists(local_weights) else None
                self.extractor = XFeat(weights=weights_arg, top_k=4096)
            else:
                try:
                    self.extractor = torch.hub.load('verlab/accelerated_features', 'XFeat', pretrained=True, top_k=4096)
                except Exception as e:
                    torch_hub_cache = os.path.expanduser("~/.cache/torch/hub/verlab_accelerated_features_main")
                    if os.path.exists(torch_hub_cache):
                        self.extractor = torch.hub.load(torch_hub_cache, 'XFeat', source='local', pretrained=True, top_k=4096)
                    else:
                        raise RuntimeError(f"Failed to load XFeat online and local repository not found at {local_xfeat_repo}: {e}")

            self.extractor = self.extractor.half().cuda().eval()

            state_dict = copy.deepcopy(self.extractor.state_dict())
            self.extractor.net = XFeatModel(4).half().cuda().eval()
            self.extractor.load_state_dict(state_dict)
            def preprocess_tensor(x):
                H, W = x.shape[-2:]
                _H, _W = (H//32) * 32, (W//32) * 32
                rh, rw = H/_H, W/_W

                x = F.interpolate(x, (_H, _W), mode='bilinear', align_corners=True)
                return x, rh, rw
            
            @torch.no_grad()
            def extract(x):
                _, _, H, W = x.shape
                x, rh1, rw1 = preprocess_tensor(x)
                
                M1 = self.extractor.net(x)

                M1 = F.normalize(M1, dim=1)
                M1 = M1[0].permute(1, 2, 0)
                return M1

            self.extractor.forward = extract

            self.extractor = torch.jit.trace(self.extractor, [dummy_img])
            self.extractor = torch.jit.script(self.extractor)
            os.makedirs(os.path.dirname(cache_path), exist_ok=True)
            torch.jit.save(self.extractor, cache_path)

        self.extractor(torch.rand_like(dummy_img))

    @torch.no_grad()
    def __call__(self, image):
        return self.extractor(image[None].half())
    