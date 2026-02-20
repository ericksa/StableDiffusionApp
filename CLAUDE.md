# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

This is a SwiftUI-based macOS application that generates images using Stable Diffusion with Core ML. The app provides a native macOS interface for text-to-image generation with support for multiple Core ML models.

## Build and Run

```bash
# Open in Xcode
open StableDiffusionApp.xcodeproj

# Build from command line
xcodebuild -scheme StableDiffusionApp -configuration Debug build

# Run from command line
xcodebuild -scheme StableDiffusionApp -configuration Debug run
```

## Architecture

The app follows a SwiftUI + ViewModel architecture pattern:

### Core Components

- **ContentView** (`Sources/ContentView.swift`): Main UI view containing the generation interface, prompt input, and image display
- **SDViewModel** (`Sources/SDViewModel.swift`): Central view model that orchestrates image generation, model management, and state management
- **ModelManager** (`Sources/ModelManager.swift`): Handles Core ML model loading, caching, and management
- **ImageGenerator** (`Sources/ImageGenerator.swift`): Wraps the StableDiffusion pipeline and handles the actual image generation process
- **ModelDownloadView** (`Sources/ModelDownloadView.swift`): UI for downloading and managing models from Hugging Face

### Key Design Patterns

1. **Async/Await Concurrency**: All generation operations use Swift's async/await pattern. The `ImageGenerator` runs generation in a detached task to maintain UI responsiveness.

2. **Pipeline Caching**: The `ModelManager` caches loaded StableDiffusionPipeline instances to avoid reloading models between generations.

3. **State Management**: The `SDViewModel` uses `@Published` properties for reactive UI updates, with distinct states for ready, generating, and completed.

4. **Model Configuration**: Models are configured using `MLModelConfiguration` with specific compute unit settings optimized for Stable Diffusion.

## Model Management

Models are stored in `~/Documents/StableDiffusionAppModels/` and must be in Core ML format. The app supports:
- Loading local Core ML models
- Downloading models from Hugging Face
- Automatic pipeline caching for performance

## Important Implementation Details

- **Resource Management**: The `ImageGenerator` properly disposes of the StableDiffusion pipeline after each generation to free resources
- **Error Handling**: Network operations and model loading include comprehensive error handling with user-facing error messages
- **Progress Tracking**: Generation progress is tracked and displayed in the UI via the view model
- **Image Persistence**: Generated images are automatically saved to the user's Photos library
