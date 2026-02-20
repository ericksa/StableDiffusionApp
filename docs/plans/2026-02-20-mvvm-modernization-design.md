# MVVM Modernization & Multi-Model Support Design

**Date:** 2026-02-20
**Status:** Approved
**Goal:** Full modernization with SD 1.5, SDXL, and SD3 support

## Overview

Refactor the Stable Diffusion app from a single-file architecture to a clean MVVM pattern with support for multiple Stable Diffusion model versions (SD 1.5, SD 2.x, SDXL, SD3), flexible image sizes, GPU compute, and comprehensive settings UI.

## Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                        View Layer                            │
│  ┌─────────────┐  ┌──────────────┐  ┌───────────────────┐   │
│  │ContentView  │  │SettingsView  │  │ModelSelectorView  │   │
│  └──────┬──────┘  └──────┬───────┘  └─────────┬─────────┘   │
└─────────┼────────────────┼───────────────────┼─────────────┘
          │                │                   │
          ▼                ▼                   ▼
┌─────────────────────────────────────────────────────────────┐
│                     ViewModel Layer                          │
│  ┌──────────────────────────────────────────────────────┐   │
│  │              GenerationViewModel                       │   │
│  │  - @Published state (images, progress, errors)        │   │
│  │  - Generation actions                                  │   │
│  │  - Model selection                                     │   │
│  │  - Settings management                                 │   │
│  └──────────────────────────────────────────────────────┘   │
└─────────────────────────────┬───────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────┐
│                      Model Layer                             │
│  ┌────────────────┐  ┌────────────────┐  ┌──────────────┐   │
│  │PipelineManager │  │ ModelRegistry  │  │ImageResizer  │   │
│  │ (protocol-     │  │ (detect model  │  │(dynamic sizes│   │
│  │  based)        │  │  capabilities) │  │ per model)   │   │
│  └────────────────┘  └────────────────┘  └──────────────┘   │
└─────────────────────────────────────────────────────────────┘
```

## Model Layer

### ModelType Enum

```swift
enum ModelType {
    case stableDiffusion1_5   // 512x512
    case stableDiffusion2_x   // 768x768
    case stableDiffusionXL    // 1024x1024
    case stableDiffusion3     // 1024x1024, multi-encoder (macOS 14+)

    var outputSize: CGSize { ... }
    var displayName: String { ... }
    var supportsSDXLOptions: Bool { ... }
}
```

### PipelineProvider Protocol

```swift
protocol PipelineProvider: AnyObject {
    var modelType: ModelType { get }
    func loadResources() async throws
    func generateImages(configuration: GenerationConfiguration,
                        progressHandler: ((Float) -> Void)?) async throws -> [CGImage?]
    func unloadResources()
}
```

### Concrete Implementations

- `SD15Pipeline` - Wraps `StableDiffusionPipeline`
- `SDXLPipeline` - Wraps `StableDiffusionXLPipeline`
- `SD3Pipeline` - Wraps `StableDiffusion3Pipeline` (macOS 14+)

## ViewModel Layer

### GenerationViewModel

All state in one place with `@Published` properties for reactive UI.

**Core Settings:**
| Setting | Type | Min | Max | Default | Description |
|---------|------|-----|-----|---------|-------------|
| prompt | String | - | - | "" | What to generate |
| negativePrompt | String | - | - | "" | What to avoid |
| stepCount | Int | 1 | 150 | 30 | Denoising steps |
| guidanceScale | Float | 1.0 | 30.0 | 7.5 | Prompt adherence |
| seed | UInt32 | 0 | 4,294,967,295 | random | Reproducibility |
| imageCount | Int | 1 | 4 | 1 | Images per run |

**img2img:**
| Setting | Type | Min | Max | Default | Description |
|---------|------|-----|-----|---------|-------------|
| strength | Float | 0.0 | 1.0 | 0.75 | Transformation amount |

**Scheduler:**
| Setting | Type | Options | Default | Description |
|---------|------|---------|---------|-------------|
| scheduler | Enum | PNDM, DPM++, DiscreteFlow | PNDM | Denoising algorithm |
| timestepSpacing | Enum | Linear, Leading, Trailing | Linear | Timestep distribution |
| timestepShift | Float | 0.0 | 10.0 | 3.0 | Resolution shift (SD3) |
| rngType | Enum | NumPy, PyTorch | NumPy | Random generator |

**SDXL/SD3 Micro-Conditioning:**
| Setting | Type | Min | Max | Default | Description |
|---------|------|-----|-----|---------|-------------|
| originalSize | Float | 256 | 2048 | 1024 | Original image size |
| targetSize | Float | 256 | 2048 | 1024 | Output size |
| cropsCoordsTopLeft | Float | 0 | 2048 | 0 | Crop position |
| aestheticScore | Float | 1.0 | 10.0 | 6.0 | Quality hint (positive) |
| negativeAestheticScore | Float | 1.0 | 10.0 | 2.5 | Quality hint (negative) |

**Advanced:**
| Setting | Type | Min | Max | Default | Description |
|---------|------|-----|-----|---------|-------------|
| disableSafety | Bool | - | - | true | Skip safety checker |
| useDenoisedIntermediates | Bool | - | - | false | Progress previews |
| encoderScaleFactor | Float | 0.01 | 1.0 | 0.18215 | Post-encode scale |
| decoderScaleFactor | Float | 0.01 | 1.0 | 0.18215 | Pre-decode scale |
| decoderShiftFactor | Float | 0.0 | 10.0 | 0.0 | Latent shift (SD3) |
| refinerStart | Float | 0.0 | 1.0 | 0.8 | Refiner timing (SDXL) |

**Compute:**
| Setting | Type | Options | Default | Description |
|---------|------|---------|---------|-------------|
| computeUnit | Enum | CPU Only, CPU+GPU, All | CPU+GPU | Hardware acceleration |
| reduceMemory | Bool | - | - | true | Memory efficiency mode |

## View Layer

### Structure

- **ContentView** - Main container with NavigationSplitView
- **SidebarView** - Model selection, settings (collapsible sections)
- **GenerationView** - Prompt input, image display, progress
- **ModelSelectorView** - Model picker with info
- **ModelDownloadSheet** - Download new models

### UI Components

- **SliderRow** - Slider with label and tooltip
- **PasteableTextField** - Text field with paste support
- **ProgressOverlay** - Real progress bar during generation
- **SettingsRow** - Generic row with tooltip support

### Paste Support

```swift
.onPasteCommand(of: [.plainText]) { items in
    // Handle paste
}
.contextMenu {
    Button("Paste") { ... }
    Button("Clear") { ... }
}
```

### Tooltips

Every control has `.help("description")` for hover tooltips.

## Model Management

### ModelRegistry

Auto-detects model type from directory contents:
- SD3: Has `MultiModalDiffusionTransformer.mlmodelc`, `TextEncoderT5.mlmodelc`
- SDXL: Has `TextEncoder2.mlmodelc` without T5
- SD 2.x: 768x768 encoder dimensions
- SD 1.5: Default fallback

### ModelManager

- Scan directories for models
- Download from URL with progress
- Delete/duplicate models
- Manage model storage in Documents directory

### Download Sheet

- Quick-add popular models (SD 1.5, SDXL, SD 2.1)
- Custom URL input
- Real-time download progress

## Compute Options

With 64GB M1 Max, GPU compute is viable:

```swift
enum ComputeUnit: String, CaseIterable {
    case cpuOnly = "CPU Only"
    case cpuAndGPU = "CPU + GPU"
    case all = "All (CPU + GPU + Neural Engine)"
}
```

## Image Sizing

Dynamic sizing based on model type:
- SD 1.5: 512x512
- SD 2.x: 768x768
- SDXL/SD3: 1024x1024

ImageResizer automatically sizes to match model requirements.

## File Structure

```
Sources/
├── StableDiffusionApp.swift          # App entry point
├── Models/
│   ├── ModelType.swift               # Model type enum
│   ├── ModelInfo.swift               # Model metadata
│   ├── ModelRegistry.swift           # Auto-detection
│   ├── ModelManager.swift            # Model operations
│   ├── PipelineProvider.swift        # Protocol
│   ├── SD15Pipeline.swift            # SD 1.5 implementation
│   ├── SDXLPipeline.swift            # SDXL implementation
│   └── SD3Pipeline.swift             # SD3 implementation (macOS 14+)
├── ViewModels/
│   └── GenerationViewModel.swift     # Main view model
├── Views/
│   ├── ContentView.swift             # Main container
│   ├── SidebarView.swift             # Settings sidebar
│   ├── GenerationView.swift          # Image generation area
│   ├── ModelSelectorView.swift       # Model picker
│   ├── ModelDownloadSheet.swift      # Download UI
│   └── Components/
│       ├── SliderRow.swift
│       ├── PasteableTextField.swift
│       ├── ProgressOverlay.swift
│       └── SettingsRow.swift
└── Utilities/
    ├── ImageResizer.swift            # Dynamic sizing
    └── SecureUnarchiver.swift        # Existing
```

## Implementation Phases

1. **Phase 1: Foundation** - Create Models folder, ModelType, ModelRegistry
2. **Phase 2: Pipeline Protocol** - Create PipelineProvider, migrate SD 1.5
3. **Phase 3: ViewModel** - Extract state from ContentView into GenerationViewModel
4. **Phase 4: View Refactor** - Split ContentView into modular components
5. **Phase 5: Model Management** - Add ModelManager, download functionality
6. **Phase 6: SDXL/SD3 Support** - Add new pipeline implementations
7. **Phase 7: GPU Compute** - Enable GPU option, test performance
8. **Phase 8: Polish** - Tooltips, paste support, progress fix