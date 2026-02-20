# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

A SwiftUI macOS application for generating images using Stable Diffusion with Core ML. Supports text-to-image and image-to-image generation modes.

## Build and Run

```bash
# Open in Xcode
open StableDiffusionApp.xcodeproj

# Build from command line
xcodebuild -scheme StableDiffusionApp -configuration Debug build

# Run via Swift Package Manager
swift run StableDiffusionApp
```

**Requirements:** macOS 13.1+, Swift 5.9, Xcode 15+

## Architecture

Single-view architecture with embedded business logic:

- **ContentView.swift** - Main UI and all generation logic (~500 lines). Contains prompt inputs, parameter controls, image display, and the generation pipeline integration
- **StableDiffusionApp.swift** - App entry point with window configuration
- **Utilities/ImageResizer.swift** - Core Graphics image resizing with model-aware sizing (512x512 or 768x768)
- **Utilities/SecureUnarchiver.swift** - Secure NSKeyedUnarchiver wrapper for safe data decoding

## Generation Flow

The pipeline runs in ContentView.swift:

1. Configure `MLModelConfiguration` with `computeUnits = .cpuOnly` (avoids 30+ minute GPU shader compilation)
2. Create `StableDiffusionPipeline` from compiled Core ML models
3. Configure `StableDiffusionPipeline.Configuration` with prompt, steps, guidance, seed
4. For img2img: set `strength` and `startingImage`
5. Call `pipeline.generateImages()` with progress handler

## Model Files

Compiled Core ML models (.mlmodelc) are stored in:
```
Resources/StableDiffusionModels/original/compiled/
├── TextEncoder.mlmodelc
├── Unet.mlmodelc (or UnetChunk1 + UnetChunk2 for split models)
├── VAEDecoder.mlmodelc
├── VAEEncoder.mlmodelc (required for img2img)
└── SafetyChecker.mlmodelc (optional)
```

## Dependencies

**ml-stable-diffusion** - Local package at `../ml-stable-diffusion/` (Apple's official Core ML Stable Diffusion implementation). Provides `StableDiffusionPipeline` and model wrappers.

## Key Implementation Details

- **CPU-only inference**: Explicitly set to avoid GPU/ANE compilation overhead. Slower generation but instant loading.
- **No separate ViewModel**: All state and logic in ContentView using `@State` properties
- **Model path resolution**: Searches multiple paths (bundle, current directory, hardcoded fallback)
- **Image saving**: Uses NSSavePanel for user-selected location (not Photos library)
- **Code signing**: Disabled for development (`CODE_SIGNING_ALLOWED = NO`)