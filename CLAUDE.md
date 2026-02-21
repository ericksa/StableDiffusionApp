# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

**VTS Imaging** - A SwiftUI macOS application for generating images using Stable Diffusion with Core ML. Supports text-to-image and image-to-image generation modes with multi-model support (SD 1.5, SD 2.x, SDXL, SD3).

## Build and Run

```bash
# Open in Xcode
open VTSImaging.xcodeproj

# Build from command line
xcodebuild -project VTSImaging.xcodeproj -scheme VTSImaging -configuration Debug build

# Regenerate Xcode project (if project.yml changes)
xcodegen generate
```

**Requirements:** macOS 13.1+, Swift 5.9, Xcode 15+

## Architecture

Currently transitioning from single-view to MVVM architecture:

### Current Structure
- **VTSImagingApp.swift** - App entry point
- **ContentView.swift** - Main UI and generation logic (being refactored)
- **Models/ModelType.swift** - Model type enum for SD versions

### In Progress (see `docs/plans/2026-02-20-mvvm-modernization.md`)
- **Models/** - ModelType, ModelInfo, ModelRegistry, PipelineProvider, GenerationConfiguration
- **ViewModels/** - GenerationViewModel with all state
- **Views/** - SidebarView, GenerationView, Components

## Generation Flow

1. Configure `MLModelConfiguration` with compute units (CPU-only for faster loading, GPU/ANE for speed)
2. Create `StableDiffusionPipeline` from compiled Core ML models
3. Configure `StableDiffusionPipeline.Configuration` with prompt, steps, guidance, seed
4. For img2img: resize input to model's expected size (512x512, 768x768, or 1024x1024)
5. Call `pipeline.generateImages()` with progress handler

## Model Files

Compiled Core ML models (.mlmodelc) stored in `Resources/StableDiffusionModels/original/compiled/`:
- **TextEncoder.mlmodelc** - Text embedding
- **Unet.mlmodelc** (or UnetChunk1 + UnetChunk2) - Denoising
- **VAEDecoder.mlmodelc** - Image generation
- **VAEEncoder.mlmodelc** - Image encoding (required for img2img)
- **SafetyChecker.mlmodelc** - Optional content filtering

## Dependencies

**ml-stable-diffusion** - Local package at `../ml-stable-diffusion/` (Apple's Core ML Stable Diffusion). Provides `StableDiffusionPipeline`, `StableDiffusionXLPipeline`, `StableDiffusion3Pipeline`.

## Implementation Plan

See `docs/plans/2026-02-20-mvvm-modernization.md` for the detailed task-by-task implementation plan for MVVM refactor and multi-model support.