"""
Convert PyTorch pretrained ResNet-18 weights to MATLAB-compatible format.
Saves weights as a .mat file that MATLAB can load.
"""
import torch
import torchvision.models as models
import numpy as np
import scipy.io as sio
import os
import sys

def extract_resnet18_weights():
    """Load pretrained ResNet-18 and extract weights as numpy arrays."""
    print("Loading pretrained ResNet-18 from torchvision...")
    model = models.resnet18(weights=models.ResNet18_Weights.IMAGENET1K_V1)
    model.eval()
    
    weights = {}
    
    # Extract weights layer by layer
    for name, param in model.named_parameters():
        weights[name] = param.detach().numpy()
    
    print(f"Extracted {len(weights)} parameter tensors")
    
    # Print layer names and shapes
    for name, arr in weights.items():
        print(f"  {name}: {arr.shape}")
    
    return weights

def save_for_matlab(weights, output_path):
    """Save weights in MATLAB-compatible .mat format.
    
    MATLAB doesn't support dots in struct field names, so we convert:
    'layer1.0.conv1.weight' -> 'layer1_0_conv1_weight'
    """
    print(f"\nSaving to {output_path}...")
    
    # Convert dot-separated names to underscore-separated for MATLAB
    matlab_weights = {}
    for name, arr in weights.items():
        matlab_name = name.replace('.', '_')
        matlab_weights[matlab_name] = arr
    
    # scipy.io.savemat can save numpy arrays directly
    sio.savemat(output_path, matlab_weights, do_compression=True)
    
    file_size = os.path.getsize(output_path)
    print(f"Saved: {output_path} ({file_size / 1024 / 1024:.1f} MB)")
    print(f"Layer names converted to MATLAB format (dots -> underscores)")

def main():
    output_dir = os.path.join(os.environ.get('TEMP', '/tmp'), 'resnet18_matlab')
    os.makedirs(output_dir, exist_ok=True)
    
    output_path = os.path.join(output_dir, 'resnet18_imagenet_weights.mat')
    
    weights = extract_resnet18_weights()
    save_for_matlab(weights, output_path)
    
    print("\nDone! MATLAB can now load these weights with:")
    print(f"  load('{output_path}');")

if __name__ == '__main__':
    main()
