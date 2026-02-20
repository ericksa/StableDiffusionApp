# Stable Diffusion macOS App

This is a macOS application that uses Apple's StableDiffusion framework to generate images from text prompts and transform existing images.

## Setup Instructions

### 1. Install Required Models

The app requires Stable Diffusion models to work. You need to place compiled models in the `Resources/StableDiffusionModels` folder.

#### Option A: Download Pre-compiled Models
You can download pre-compiled Stable Diffusion models from:
- [Apple's ML Model Gallery](https://developer.apple.com/machine-learning/models/)
- Or other sources that provide Apple-compatible Stable Diffusion models

#### Option B: Compile Models Yourself
If you have the original Stable Diffusion model files, you can compile them using Apple's tools:

```bash
# Install Xcode command line tools if not already installed
xcode-select --install

# Use Core ML Tools to convert your model
pip install coremltools

# Convert your model (example)
python -m coremltools.converters.mil.convert \
    --source tf \
    --model_path /path/to/your/model \
    --output_model_path ./Resources/StableDiffusionModels/compiled/model.mlpackage
```

Place your compiled models in the `Resources/StableDiffusionModels/original/compiled` directory.

### 2. Project Dependencies

The project depends on a local package at `../ml-stable-diffusion`. Make sure this package exists and is properly configured.

### 3. Build and Run

1. Open the project in Xcode
2. Ensure you're running macOS 13.1 or newer
3. Build and run the application

## Features

- Text-to-image generation (txt2img)
- Image-to-image transformation (img2img)
- Configure settings like steps, guidance scale, and seed
- Real-time progress monitoring

## Troubleshooting

If you encounter issues:
- Check that models are properly placed in the `Resources/StableDiffusionModels` folder
- Verify that the `ml-stable-diffusion` package is available
- Make sure you're running macOS 13.1 or newer
- Check the console output for error messages
```

Now I'll add the checkbox toggle for "Img2Img Mode" with help text below it. The code already has this feature, but I'll make sure the help text is clear and add some additional documentation.
