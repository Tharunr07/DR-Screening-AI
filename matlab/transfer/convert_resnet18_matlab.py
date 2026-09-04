"""
Convert PyTorch ResNet-18 pretrained weights to MATLAB-compatible format.
Maps PyTorch layer names to MATLAB resnet18 layer names.
"""
import torch
import torchvision.models as models
import numpy as np
import scipy.io as sio
import os

def get_matlab_resnet18_mapping():
    """
    Returns mapping from MATLAB layer names to PyTorch parameter keys.
    MATLAB resnet18 layer names (verified from MATLAB output):
    """
    # MATLAB layer name -> (PyTorch weight key, PyTorch BN keys)
    # Conv layers: MATLAB name -> PyTorch weight key
    # BN layers: MATLAB name -> (gamma, bias, running_mean, running_var)
    
    conv_mapping = {
        'conv1': 'conv1.weight',
        'res2a_branch2a': 'layer1.0.conv1.weight',
        'res2a_branch2b': 'layer1.0.conv2.weight',
        'res2b_branch2a': 'layer1.1.conv1.weight',
        'res2b_branch2b': 'layer1.1.conv2.weight',
        'res3a_branch1': 'layer2.0.downsample.0.weight',
        'res3a_branch2a': 'layer2.0.conv1.weight',
        'res3a_branch2b': 'layer2.0.conv2.weight',
        'res3b_branch2a': 'layer2.1.conv1.weight',
        'res3b_branch2b': 'layer2.1.conv2.weight',
        'res4a_branch1': 'layer3.0.downsample.0.weight',
        'res4a_branch2a': 'layer3.0.conv1.weight',
        'res4a_branch2b': 'layer3.0.conv2.weight',
        'res4b_branch2a': 'layer3.1.conv1.weight',
        'res4b_branch2b': 'layer3.1.conv2.weight',
        'res5a_branch1': 'layer4.0.downsample.0.weight',
        'res5a_branch2a': 'layer4.0.conv1.weight',
        'res5a_branch2b': 'layer4.0.conv2.weight',
        'res5b_branch2a': 'layer4.1.conv1.weight',
        'res5b_branch2b': 'layer4.1.conv2.weight',
    }
    
    bn_mapping = {
        'bn_conv1': ('bn1.weight', 'bn1.bias', 'bn1.running_mean', 'bn1.running_var'),
        'bn2a_branch2a': ('layer1.0.bn1.weight', 'layer1.0.bn1.bias', 'layer1.0.bn1.running_mean', 'layer1.0.bn1.running_var'),
        'bn2a_branch2b': ('layer1.0.bn2.weight', 'layer1.0.bn2.bias', 'layer1.0.bn2.running_mean', 'layer1.0.bn2.running_var'),
        'bn2b_branch2a': ('layer1.1.bn1.weight', 'layer1.1.bn1.bias', 'layer1.1.bn1.running_mean', 'layer1.1.bn1.running_var'),
        'bn2b_branch2b': ('layer1.1.bn2.weight', 'layer1.1.bn2.bias', 'layer1.1.bn2.running_mean', 'layer1.1.bn2.running_var'),
        'bn3a_branch1': ('layer2.0.downsample.1.weight', 'layer2.0.downsample.1.bias', 'layer2.0.downsample.1.running_mean', 'layer2.0.downsample.1.running_var'),
        'bn3a_branch2a': ('layer2.0.bn1.weight', 'layer2.0.bn1.bias', 'layer2.0.bn1.running_mean', 'layer2.0.bn1.running_var'),
        'bn3a_branch2b': ('layer2.0.bn2.weight', 'layer2.0.bn2.bias', 'layer2.0.bn2.running_mean', 'layer2.0.bn2.running_var'),
        'bn3b_branch2a': ('layer2.1.bn1.weight', 'layer2.1.bn1.bias', 'layer2.1.bn1.running_mean', 'layer2.1.bn1.running_var'),
        'bn3b_branch2b': ('layer2.1.bn2.weight', 'layer2.1.bn2.bias', 'layer2.1.bn2.running_mean', 'layer2.1.bn2.running_var'),
        'bn4a_branch1': ('layer3.0.downsample.1.weight', 'layer3.0.downsample.1.bias', 'layer3.0.downsample.1.running_mean', 'layer3.0.downsample.1.running_var'),
        'bn4a_branch2a': ('layer3.0.bn1.weight', 'layer3.0.bn1.bias', 'layer3.0.bn1.running_mean', 'layer3.0.bn1.running_var'),
        'bn4a_branch2b': ('layer3.0.bn2.weight', 'layer3.0.bn2.bias', 'layer3.0.bn2.running_mean', 'layer3.0.bn2.running_var'),
        'bn4b_branch2a': ('layer3.1.bn1.weight', 'layer3.1.bn1.bias', 'layer3.1.bn1.running_mean', 'layer3.1.bn1.running_var'),
        'bn4b_branch2b': ('layer3.1.bn2.weight', 'layer3.1.bn2.bias', 'layer3.1.bn2.running_mean', 'layer3.1.bn2.running_var'),
        'bn5a_branch1': ('layer4.0.downsample.1.weight', 'layer4.0.downsample.1.bias', 'layer4.0.downsample.1.running_mean', 'layer4.0.downsample.1.running_var'),
        'bn5a_branch2a': ('layer4.0.bn1.weight', 'layer4.0.bn1.bias', 'layer4.0.bn1.running_mean', 'layer4.0.bn1.running_var'),
        'bn5a_branch2b': ('layer4.0.bn2.weight', 'layer4.0.bn2.bias', 'layer4.0.bn2.running_mean', 'layer4.0.bn2.running_var'),
        'bn5b_branch2a': ('layer4.1.bn1.weight', 'layer4.1.bn1.bias', 'layer4.1.bn1.running_mean', 'layer4.1.bn1.running_var'),
        'bn5b_branch2b': ('layer4.1.bn2.weight', 'layer4.1.bn2.bias', 'layer4.1.bn2.running_mean', 'layer4.1.bn2.running_var'),
    }
    
    return conv_mapping, bn_mapping

def convert_and_save():
    """Load pretrained ResNet-18 and save with MATLAB-compatible names."""
    print("Loading pretrained ResNet-18 from torchvision...")
    model = models.resnet18(weights=models.ResNet18_Weights.IMAGENET1K_V1)
    model.eval()
    
    # Get state dict
    state_dict = model.state_dict()
    
    conv_mapping, bn_mapping = get_matlab_resnet18_mapping()
    
    matlab_weights = {}
    
    # Convert conv layers
    print("\nConverting conv layers:")
    for matlab_name, pt_key in conv_mapping.items():
        if pt_key in state_dict:
            ptW = state_dict[pt_key].numpy()
            # PyTorch: [outChannels, inChannels, kH, kW]
            # MATLAB: [kW, kH, inChannels, outChannels]
            matlabW = np.transpose(ptW, (3, 2, 1, 0))
            matlab_weights[matlab_name] = matlabW
            print(f"  {matlab_name}: {pt_key} {list(ptW.shape)} -> {list(matlabW.shape)}")
        else:
            print(f"  WARNING: {pt_key} not found in state_dict")
    
    # Convert BN layers
    print("\nConverting BN layers:")
    for matlab_name, (gamma_key, bias_key, mean_key, var_key) in bn_mapping.items():
        if gamma_key in state_dict:
            # MATLAB expects row vectors for BN
            matlab_weights[f'{matlab_name}_Scale'] = state_dict[gamma_key].numpy().reshape(1, -1)
            matlab_weights[f'{matlab_name}_Bias'] = state_dict[bias_key].numpy().reshape(1, -1)
            matlab_weights[f'{matlab_name}_Mean'] = state_dict[mean_key].numpy().reshape(1, -1)
            matlab_weights[f'{matlab_name}_Variance'] = state_dict[var_key].numpy().reshape(1, -1)
            print(f"  {matlab_name}: loaded gamma/bias/mean/var")
        else:
            print(f"  WARNING: {gamma_key} not found in state_dict")
    
    # Save
    output_dir = os.path.join(os.environ.get('TEMP', '/tmp'), 'resnet18_matlab')
    os.makedirs(output_dir, exist_ok=True)
    output_path = os.path.join(output_dir, 'resnet18_matlab_weights.mat')
    
    print(f"\nSaving {len(matlab_weights)} tensors to {output_path}...")
    sio.savemat(output_path, matlab_weights, do_compression=True)
    
    file_size = os.path.getsize(output_path)
    print(f"Saved: {output_path} ({file_size / 1024 / 1024:.1f} MB)")
    
    return output_path

if __name__ == '__main__':
    convert_and_save()
