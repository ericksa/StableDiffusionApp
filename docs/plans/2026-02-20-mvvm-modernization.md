# VTS Imaging - MVVM Modernization Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Refactor the Stable Diffusion app to MVVM architecture with multi-model support (SD 1.5, SDXL, SD3), GPU compute, and comprehensive settings UI. Rename project to "VTS Imaging".

**Architecture:** Protocol-based pipeline abstraction with a single GenerationViewModel holding all state. Views are modular SwiftUI components with tooltips and paste support. Model registry auto-detects model type from directory contents.

**Tech Stack:** SwiftUI, Combine, Core ML, ml-stable-diffusion library, async/await

---

## Phase 0: Project Rename to "VTS Imaging"

### Task 0.1: Rename Project in Xcode Project Settings

**Files:**
- Modify: `project.yml`
- Modify: `Sources/Info.plist`
- Modify: `Sources/StableDiffusionApp.swift`

**Step 1: Update project.yml**

Change:
```yaml
name: StableDiffusionApp
```
To:
```yaml
name: VTSImaging
```

And update bundle identifier if desired:
```yaml
PRODUCT_BUNDLE_IDENTIFIER: com.vts.imaging
```

**Step 2: Update Info.plist**

Update CFBundleName and CFBundleDisplayName to "VTS Imaging"

**Step 3: Update app entry point filename (optional)**

Rename `StableDiffusionApp.swift` to `VTSImagingApp.swift` and update struct name.

**Step 4: Regenerate Xcode project**

```bash
xcodegen generate
```

**Step 5: Build and verify**

Run: `xcodebuild -scheme VTSImaging -configuration Debug build 2>&1 | tail -5`
Expected: BUILD SUCCEEDED

**Step 6: Commit**

```bash
git add -A
git commit -m "refactor: rename project to VTS Imaging"
```

---

## Phase 1: Foundation - Model Types & Registry

### Task 1.1: Create ModelType Enum

**Files:**
- Create: `Sources/Models/ModelType.swift`

**Step 1: Create the Models directory and file**

```bash
mkdir -p Sources/Models
```

**Step 2: Write ModelType enum**

```swift
// Sources/Models/ModelType.swift
import Foundation
import CoreGraphics

@available(macOS 13.1, *)
enum ModelType: String, CaseIterable, Identifiable {
    case stableDiffusion1_5 = "SD 1.5"
    case stableDiffusion2_x = "SD 2.x"
    case stableDiffusionXL = "SDXL"
    case stableDiffusion3 = "SD3"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .stableDiffusion1_5: return "Stable Diffusion 1.5"
        case .stableDiffusion2_x: return "Stable Diffusion 2.x"
        case .stableDiffusionXL: return "SDXL"
        case .stableDiffusion3: return "Stable Diffusion 3"
        }
    }

    var outputSize: CGSize {
        switch self {
        case .stableDiffusion1_5: return CGSize(width: 512, height: 512)
        case .stableDiffusion2_x: return CGSize(width: 768, height: 768)
        case .stableDiffusionXL, .stableDiffusion3: return CGSize(width: 1024, height: 1024)
        }
    }

    var outputSizeLabel: String {
        let size = outputSize
        return "\(Int(size.width))×\(Int(size.height))"
    }

    var supportsSDXLOptions: Bool {
        self == .stableDiffusionXL || self == .stableDiffusion3
    }

    var minimumMacOSVersion: String {
        switch self {
        case .stableDiffusion1_5, .stableDiffusion2_x, .stableDiffusionXL:
            return "macOS 13.1"
        case .stableDiffusion3:
            return "macOS 14.0"
        }
    }
}
```

**Step 3: Build to verify**

Run: `xcodebuild -scheme StableDiffusionApp -configuration Debug build 2>&1 | tail -5`
Expected: BUILD SUCCEEDED

**Step 4: Commit**

```bash
git add Sources/Models/ModelType.swift
git commit -m "feat: add ModelType enum for multi-model support"
```

---

### Task 1.2: Create ModelInfo Struct

**Files:**
- Create: `Sources/Models/ModelInfo.swift`

**Step 1: Write ModelInfo struct**

```swift
// Sources/Models/ModelInfo.swift
import Foundation

@available(macOS 13.1, *)
struct ModelInfo: Identifiable, Hashable {
    let id: UUID
    let name: String
    let type: ModelType
    let url: URL
    let size: Int64

    init(id: UUID = UUID(), name: String, type: ModelType, url: URL, size: Int64 = 0) {
        self.id = id
        self.name = name
        self.type = type
        self.url = url
        self.size = size
    }

    var formattedSize: String {
        ByteCountFormatter.string(fromByteCount: size, countStyle: .file)
    }

    var isAvailable: Bool {
        FileManager.default.fileExists(atPath: url.path)
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }

    static func == (lhs: ModelInfo, rhs: ModelInfo) -> Bool {
        lhs.id == rhs.id
    }
}
```

**Step 2: Build to verify**

Run: `xcodebuild -scheme StableDiffusionApp -configuration Debug build 2>&1 | tail -5`
Expected: BUILD SUCCEEDED

**Step 3: Commit**

```bash
git add Sources/Models/ModelInfo.swift
git commit -m "feat: add ModelInfo struct for model metadata"
```

---

### Task 1.3: Create ModelRegistry for Auto-Detection

**Files:**
- Create: `Sources/Models/ModelRegistry.swift`

**Step 1: Write ModelRegistry**

```swift
// Sources/Models/ModelRegistry.swift
import Foundation

@available(macOS 13.1, *)
class ModelRegistry {

    /// Detect model type from directory contents
    static func detectModelType(at url: URL) -> ModelType {
        let fileManager = FileManager.default

        // Check for SD3-specific files
        let mmditPath = url.appendingPathComponent("MultiModalDiffusionTransformer.mlmodelc").path
        let t5Path = url.appendingPathComponent("TextEncoderT5.mlmodelc").path

        if fileManager.fileExists(atPath: mmditPath) {
            return .stableDiffusion3
        }

        // Check for SDXL-specific files (TextEncoder2 but no T5)
        let textEncoder2Path = url.appendingPathComponent("TextEncoder2.mlmodelc").path
        if fileManager.fileExists(atPath: textEncoder2Path) && !fileManager.fileExists(atPath: t5Path) {
            return .stableDiffusionXL
        }

        // Check for SD 2.x (768x768 encoder) - check model config if available
        let encoderPath = url.appendingPathComponent("VAEEncoder.mlmodelc")
        if let encoderSize = getEncoderInputSize(at: encoderPath) {
            if encoderSize == 768 {
                return .stableDiffusion2_x
            }
        }

        // Default to SD 1.5
        return .stableDiffusion1_5
    }

    /// Get encoder input size from model metadata
    private static func getEncoderInputSize(at url: URL) -> Int? {
        let metadataPath = url.appendingPathComponent("metadata.json")
        guard let data = try? Data(contentsOf: metadataPath),
              let json = try? JSONSerialization.jsonObject(with: data) as? [[String: Any]] else {
            return nil
        }

        // Parse input schema to find dimensions
        if let inputSchema = json.first?["inputSchema"] as? [[String: Any]] {
            if let shape = inputSchema.first?["shape"] as? String {
                // Parse "[1, 3, 512, 512]" or similar
                let numbers = shape.trimmingCharacters(in: CharacterSet(charactersIn: "[]"))
                    .split(separator: ",")
                    .compactMap { Int($0.trimmingCharacters(in: .whitespaces)) }
                if numbers.count >= 3 {
                    return numbers[2] // Height dimension
                }
            }
        }
        return nil
    }

    /// Scan a directory for valid models
    static func scanDirectory(_ directory: URL) -> [ModelInfo] {
        let fileManager = FileManager.default
        var models: [ModelInfo] = []

        guard let enumerator = fileManager.enumerator(
            at: directory,
            includingPropertiesForKeys: [.isDirectoryKey],
            options: [.skipsHiddenFiles]
        ) else { return models }

        for case let url as URL in enumerator {
            guard let resourceValues = try? url.resourceValues(forKeys: [.isDirectoryKey]),
                  resourceValues.isDirectory == true else { continue }

            // Check for compiled model directory (.mlmodelc)
            let compiledPath = url.appendingPathComponent("compiled")
            if fileManager.fileExists(atPath: compiledPath.path) {
                let modelType = detectModelType(at: compiledPath)
                let size = calculateDirectorySize(at: compiledPath)

                models.append(ModelInfo(
                    name: url.lastPathComponent,
                    type: modelType,
                    url: compiledPath,
                    size: size
                ))
            }

            // Also check direct .mlmodelc files
            let textEncoderPath = url.appendingPathComponent("TextEncoder.mlmodelc").path
            if fileManager.fileExists(atPath: textEncoderPath) {
                let modelType = detectModelType(at: url)
                let size = calculateDirectorySize(at: url)

                models.append(ModelInfo(
                    name: url.lastPathComponent,
                    type: modelType,
                    url: url,
                    size: size
                ))
            }
        }

        return models
    }

    /// Calculate total size of directory
    private static func calculateDirectorySize(at url: URL) -> Int64 {
        let fileManager = FileManager.default
        var totalSize: Int64 = 0

        guard let enumerator = fileManager.enumerator(
            at: url,
            includingPropertiesForKeys: [.fileSizeKey],
            options: [.skipsHiddenFiles]
        ) else { return 0 }

        for case let fileURL as URL in enumerator {
            if let resourceValues = try? fileURL.resourceValues(forKeys: [.fileSizeKey]) {
                totalSize += Int64(resourceValues.fileSize ?? 0)
            }
        }

        return totalSize
    }
}
```

**Step 2: Build to verify**

Run: `xcodebuild -scheme StableDiffusionApp -configuration Debug build 2>&1 | tail -5`
Expected: BUILD SUCCEEDED

**Step 3: Commit**

```bash
git add Sources/Models/ModelRegistry.swift
git commit -m "feat: add ModelRegistry for auto-detecting model types"
```

---

## Phase 2: Pipeline Protocol

### Task 2.1: Create PipelineProvider Protocol

**Files:**
- Create: `Sources/Models/PipelineProvider.swift`

**Step 1: Write PipelineProvider protocol**

```swift
// Sources/Models/PipelineProvider.swift
import Foundation
import CoreGraphics
import CoreML

@available(macOS 13.1, *)
protocol PipelineProvider: AnyObject {
    var modelType: ModelType { get }
    var outputSize: CGSize { get }

    func loadResources() async throws
    func generateImages(
        prompt: String,
        negativePrompt: String,
        stepCount: Int,
        guidanceScale: Float,
        seed: UInt32,
        imageCount: Int,
        startingImage: CGImage?,
        strength: Float,
        progressHandler: ((Float) -> Void)?
    ) async throws -> [CGImage?]
    func unloadResources()
}
```

**Step 2: Build to verify**

Run: `xcodebuild -scheme StableDiffusionApp -configuration Debug build 2>&1 | tail -5`
Expected: BUILD SUCCEEDED

**Step 3: Commit**

```bash
git add Sources/Models/PipelineProvider.swift
git commit -m "feat: add PipelineProvider protocol for pipeline abstraction"
```

---

### Task 2.2: Create GenerationConfiguration

**Files:**
- Create: `Sources/Models/GenerationConfiguration.swift`

**Step 1: Write GenerationConfiguration**

```swift
// Sources/Models/GenerationConfiguration.swift
import Foundation
import CoreGraphics

@available(macOS 13.1, *)
struct GenerationConfiguration {
    // Core
    var prompt: String = ""
    var negativePrompt: String = ""
    var stepCount: Int = 30
    var guidanceScale: Float = 7.5
    var seed: UInt32 = 0
    var imageCount: Int = 1

    // img2img
    var startingImage: CGImage? = nil
    var strength: Float = 0.75

    // Scheduler
    var scheduler: SchedulerType = .pndm
    var timestepSpacing: TimestepSpacing = .linspace
    var timestepShift: Float = 3.0
    var rngType: RNGType = .numpy

    // SDXL/SD3 micro-conditioning
    var originalSize: Float = 1024
    var targetSize: Float = 1024
    var cropsCoordsTopLeft: Float = 0
    var aestheticScore: Float = 6.0
    var negativeAestheticScore: Float = 2.5

    // Advanced
    var disableSafety: Bool = true
    var useDenoisedIntermediates: Bool = false
    var encoderScaleFactor: Float = 0.18215
    var decoderScaleFactor: Float = 0.18215
    var decoderShiftFactor: Float = 0.0
    var refinerStart: Float = 0.8

    // Compute
    var computeUnit: ComputeUnit = .cpuAndGPU
    var reduceMemory: Bool = true
}

@available(macOS 13.1, *)
enum SchedulerType: String, CaseIterable, Identifiable {
    case pndm = "PNDM"
    case dpmpp = "DPM++"
    case discreteFlow = "Discrete Flow"

    var id: String { rawValue }

    var tooltip: String {
        switch self {
        case .pndm: return "Standard scheduler, good for most cases"
        case .dpmpp: return "Faster scheduler, fewer steps needed"
        case .discreteFlow: return "For SD3 models"
        }
    }
}

@available(macOS 13.1, *)
enum TimestepSpacing: String, CaseIterable, Identifiable {
    case linspace = "Linear"
    case leading = "Leading"
    case trailing = "Trailing"

    var id: String { rawValue }

    var tooltip: String {
        switch self {
        case .linspace: return "Evenly spaced timesteps"
        case .leading: return "More timesteps at start"
        case .trailing: return "More timesteps at end"
        }
    }
}

@available(macOS 13.1, *)
enum RNGType: String, CaseIterable, Identifiable {
    case numpy = "NumPy"
    case pytorch = "PyTorch"

    var id: String { rawValue }

    var tooltip: String {
        switch self {
        case .numpy: return "NumPy-compatible random generator"
        case .pytorch: return "PyTorch-compatible random generator"
        }
    }
}

@available(macOS 13.1, *)
enum ComputeUnit: String, CaseIterable, Identifiable {
    case cpuOnly = "CPU Only"
    case cpuAndGPU = "CPU + GPU"
    case all = "All (CPU + GPU + NE)"

    var id: String { rawValue }

    var mlComputeUnits: MLComputeUnits {
        switch self {
        case .cpuOnly: return .cpuOnly
        case .cpuAndGPU: return .cpuAndGPU
        case .all: return .all
        }
    }

    var tooltip: String {
        switch self {
        case .cpuOnly: return "Slower but uses less memory"
        case .cpuAndGPU: return "Balanced speed and memory"
        case .all: return "Fastest, includes Neural Engine"
        }
    }
}
```

**Step 2: Build to verify**

Run: `xcodebuild -scheme StableDiffusionApp -configuration Debug build 2>&1 | tail -5`
Expected: BUILD SUCCEEDED

**Step 3: Commit**

```bash
git add Sources/Models/GenerationConfiguration.swift
git commit -m "feat: add GenerationConfiguration with all settings"
```

---

### Task 2.3: Create SD15Pipeline Implementation

**Files:**
- Create: `Sources/Models/SD15Pipeline.swift`

**Step 1: Write SD15Pipeline**

```swift
// Sources/Models/SD15Pipeline.swift
import Foundation
import CoreGraphics
import CoreML
import StableDiffusion

@available(macOS 13.1, *)
class SD15Pipeline: PipelineProvider {
    let modelType: ModelType = .stableDiffusion1_5
    let outputSize: CGSize = CGSize(width: 512, height: 512)

    private let modelURL: URL
    private let configuration: GenerationConfiguration
    private var pipeline: StableDiffusionPipeline?

    init(modelURL: URL, configuration: GenerationConfiguration) {
        self.modelURL = modelURL
        self.configuration = configuration
    }

    func loadResources() async throws {
        let mlConfig = MLModelConfiguration()
        mlConfig.computeUnits = configuration.computeUnit.mlComputeUnits

        pipeline = try StableDiffusionPipeline(
            resourcesAt: modelURL,
            controlNet: [],
            configuration: mlConfig,
            disableSafety: configuration.disableSafety,
            reduceMemory: configuration.reduceMemory
        )

        try pipeline?.loadResources()
    }

    func generateImages(
        prompt: String,
        negativePrompt: String,
        stepCount: Int,
        guidanceScale: Float,
        seed: UInt32,
        imageCount: Int,
        startingImage: CGImage?,
        strength: Float,
        progressHandler: ((Float) -> Void)?
    ) async throws -> [CGImage?] {
        guard let pipeline = pipeline else {
            throw NSError(domain: "PipelineError", code: 1, userInfo: [NSLocalizedDescriptionKey: "Pipeline not loaded"])
        }

        var config = StableDiffusionPipeline.Configuration(prompt: prompt)
        config.negativePrompt = negativePrompt
        config.stepCount = stepCount
        config.guidanceScale = guidanceScale
        config.seed = seed
        config.imageCount = imageCount
        config.strength = strength
        config.startingImage = startingImage
        config.disableSafety = configuration.disableSafety
        config.useDenoisedIntermediates = configuration.useDenoisedIntermediates

        // Map scheduler
        switch configuration.scheduler {
        case .pndm:
            config.schedulerType = .pndmScheduler
        case .dpmpp:
            config.schedulerType = .dpmSolverMultistepScheduler
        case .discreteFlow:
            config.schedulerType = .pndmScheduler // Fallback for SD 1.5
        }

        let images = try pipeline.generateImages(
            configuration: config,
            progressHandler: { progress in
                progressHandler?(Float(progress.step) / Float(progress.stepCount))
                return true
            }
        )

        return images
    }

    func unloadResources() {
        pipeline?.unloadResources()
        pipeline = nil
    }
}
```

**Step 2: Build to verify**

Run: `xcodebuild -scheme StableDiffusionApp -configuration Debug build 2>&1 | tail -5`
Expected: BUILD SUCCEEDED

**Step 3: Commit**

```bash
git add Sources/Models/SD15Pipeline.swift
git commit -m "feat: add SD15Pipeline implementing PipelineProvider"
```

---

## Phase 3: ViewModel

### Task 3.1: Create GenerationViewModel

**Files:**
- Create: `Sources/ViewModels/GenerationViewModel.swift`

**Step 1: Create ViewModels directory**

```bash
mkdir -p Sources/ViewModels
```

**Step 2: Write GenerationViewModel (Part 1 - State)**

```swift
// Sources/ViewModels/GenerationViewModel.swift
import Foundation
import CoreGraphics
import Combine

@MainActor
@available(macOS 13.1, *)
class GenerationViewModel: ObservableObject {

    // MARK: - Published State

    // Generation State
    @Published var generatedImages: [NSImage?] = []
    @Published var selectedImageIndex: Int = 0
    @Published var inputImage: NSImage?
    @Published var isGenerating: Bool = false
    @Published var progress: Float = 0
    @Published var errorMessage: String?

    // Model State
    @Published var availableModels: [ModelInfo] = []
    @Published var selectedModel: ModelInfo?
    @Published var modelType: ModelType = .stableDiffusion1_5

    // Core Settings
    @Published var prompt: String = ""
    @Published var negativePrompt: String = ""
    @Published var stepCount: Double = 30
    @Published var guidanceScale: Double = 7.5
    @Published var seed: UInt32 = 0
    @Published var imageCount: Int = 1

    // img2img Settings
    @Published var isImg2ImgMode: Bool = false
    @Published var strength: Double = 0.75

    // Scheduler Settings
    @Published var scheduler: SchedulerType = .pndm
    @Published var timestepSpacing: TimestepSpacing = .linspace
    @Published var timestepShift: Double = 3.0
    @Published var rngType: RNGType = .numpy

    // SDXL/SD3 Settings
    @Published var originalSize: Double = 1024
    @Published var targetSize: Double = 1024
    @Published var cropsCoordsTopLeft: Double = 0
    @Published var aestheticScore: Double = 6.0
    @Published var negativeAestheticScore: Double = 2.5

    // Advanced Settings
    @Published var disableSafety: Bool = true
    @Published var useDenoisedIntermediates: Bool = false
    @Published var encoderScaleFactor: Double = 0.18215
    @Published var decoderScaleFactor: Double = 0.18215
    @Published var decoderShiftFactor: Double = 0.0
    @Published var refinerStart: Double = 0.8

    // Compute Settings
    @Published var computeUnit: ComputeUnit = .cpuAndGPU
    @Published var reduceMemory: Bool = true

    // MARK: - Private
    private var pipeline: PipelineProvider?
    private let modelRegistry = ModelRegistry()

    // MARK: - Computed Properties

    var generatedImage: NSImage? {
        guard selectedImageIndex < generatedImages.count else { return nil }
        return generatedImages[selectedImageIndex]
    }

    var outputSize: CGSize {
        modelType.outputSize
    }

    // Continue in Part 2...
}
```

**Step 3: Add GenerationViewModel (Part 2 - Actions)**

```swift
// Add to GenerationViewModel.swift

// MARK: - Actions

func generateImage() async {
    guard !prompt.isEmpty else {
        errorMessage = "Please enter a prompt"
        return
    }

    guard let model = selectedModel else {
        errorMessage = "Please select a model"
        return
    }

    // Validate img2img
    if isImg2ImgMode && inputImage == nil {
        errorMessage = "Please select an input image for img2img"
        return
    }

    isGenerating = true
    errorMessage = nil
    progress = 0
    generatedImages = []

    do {
        // Create configuration
        var config = GenerationConfiguration()
        config.prompt = prompt
        config.negativePrompt = negativePrompt
        config.stepCount = Int(stepCount)
        config.guidanceScale = Float(guidanceScale)
        config.seed = seed
        config.imageCount = imageCount
        config.strength = Float(strength)
        config.scheduler = scheduler
        config.timestepSpacing = timestepSpacing
        config.timestepShift = Float(timestepShift)
        config.rngType = rngType
        config.originalSize = Float(originalSize)
        config.targetSize = Float(targetSize)
        config.cropsCoordsTopLeft = Float(cropsCoordsTopLeft)
        config.aestheticScore = Float(aestheticScore)
        config.negativeAestheticScore = Float(negativeAestheticScore)
        config.disableSafety = disableSafety
        config.useDenoisedIntermediates = useDenoisedIntermediates
        config.encoderScaleFactor = Float(encoderScaleFactor)
        config.decoderScaleFactor = Float(decoderScaleFactor)
        config.decoderShiftFactor = Float(decoderShiftFactor)
        config.refinerStart = Float(refinerStart)
        config.computeUnit = computeUnit
        config.reduceMemory = reduceMemory

        // Create pipeline for selected model
        pipeline = SD15Pipeline(modelURL: model.url, configuration: config)

        try await pipeline?.loadResources()

        // Prepare starting image for img2img
        var startingCGImage: CGImage? = nil
        if isImg2ImgMode, let input = inputImage {
            startingCGImage = input.cgImage(forProposedRect: nil, context: nil, hints: nil)
        }

        // Generate
        let images = try await pipeline?.generateImages(
            prompt: prompt,
            negativePrompt: negativePrompt,
            stepCount: Int(stepCount),
            guidanceScale: Float(guidanceScale),
            seed: seed,
            imageCount: imageCount,
            startingImage: startingCGImage,
            strength: Float(strength),
            progressHandler: { [weak self] p in
                Task { @MainActor in
                    self?.progress = p
                }
            }
        )

        // Convert to NSImages
        generatedImages = images?.map { cgImage in
            guard let cgImage = cgImage else { return nil }
            return NSImage(cgImage: cgImage, size: NSSize(width: cgImage.width, height: cgImage.height))
        } ?? []

        selectedImageIndex = 0
        progress = 1.0

    } catch {
        errorMessage = "Generation failed: \(error.localizedDescription)"
    }

    isGenerating = false
}

func cancelGeneration() {
    // TODO: Implement cancellation
    isGenerating = false
}

func randomizeSeed() {
    seed = UInt32.random(in: 0...UInt32.max)
}

func scanForModels() async {
    // Scan app bundle
    var models: [ModelInfo] = []

    if let bundleURL = Bundle.main.resourceURL?.appendingPathComponent("StableDiffusionModels") {
        models.append(contentsOf: ModelRegistry.scanDirectory(bundleURL))
    }

    // Scan documents directory
    let documentsURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
    let modelsURL = documentsURL.appendingPathComponent("StableDiffusionModels")
    models.append(contentsOf: ModelRegistry.scanDirectory(modelsURL))

    availableModels = models

    // Auto-select first model if none selected
    if selectedModel == nil && !models.isEmpty {
        selectedModel = models.first
        modelType = models.first?.type ?? .stableDiffusion1_5
    }
}

func selectModel(_ model: ModelInfo) {
    selectedModel = model
    modelType = model.type
}
```

**Step 4: Build to verify**

Run: `xcodebuild -scheme StableDiffusionApp -configuration Debug build 2>&1 | tail -10`
Expected: BUILD SUCCEEDED (may have some warnings about unused variables)

**Step 5: Commit**

```bash
git add Sources/ViewModels/GenerationViewModel.swift
git commit -m "feat: add GenerationViewModel with all state and actions"
```

---

## Phase 4: View Refactor

### Task 4.1: Create Reusable Components

**Files:**
- Create: `Sources/Views/Components/SliderRow.swift`
- Create: `Sources/Views/Components/PasteableTextField.swift`

**Step 1: Create Components directory**

```bash
mkdir -p Sources/Views/Components
```

**Step 2: Write SliderRow**

```swift
// Sources/Views/Components/SliderRow.swift
import SwiftUI

@available(macOS 13.1, *)
struct SliderRow: View {
    let title: String
    let tooltip: String
    @Binding var value: Double
    let range: ClosedRange<Double>
    let step: Double

    init(title: String, tooltip: String, value: Binding<Double>, range: ClosedRange<Double>, step: Double = 1) {
        self.title = title
        self.tooltip = tooltip
        self._value = value
        self.range = range
        self.step = step
    }

    var body: some View {
        HStack {
            Text(title)
                .help(tooltip)
            Spacer()
            Slider(value: $value, in: range, step: step)
                .frame(width: 120)
            Text(String(format: "%.1f", value))
                .frame(width: 45)
                .monospacedDigit()
        }
        .help(tooltip)
    }
}
```

**Step 3: Write PasteableTextField**

```swift
// Sources/Views/Components/PasteableTextField.swift
import SwiftUI
import AppKit

@available(macOS 13.1, *)
struct PasteableTextField: View {
    let title: String
    let tooltip: String
    @Binding var text: String
    let axis: Axis
    let lineLimits: ClosedRange<Int>

    init(title: String, tooltip: String, text: Binding<String>, axis: Axis = .vertical, lineLimits: ClosedRange<Int> = 1...6) {
        self.title = title
        self.tooltip = tooltip
        self._text = text
        self.axis = axis
        self.lineLimits = lineLimits
    }

    var body: some View {
        TextField(title, text: $text, axis: axis)
            .textFieldStyle(.roundedBorder)
            .lineLimit(lineLimits)
            .help(tooltip)
            .contextMenu {
                Button("Paste") {
                    if let pasteString = NSPasteboard.general.string(forType: .string) {
                        text = pasteString
                    }
                }
                Button("Copy") {
                    NSPasteboard.general.clearContents()
                    NSPasteboard.general.setString(text, forType: .string)
                }
                Button("Clear") {
                    text = ""
                }
            }
    }
}
```

**Step 4: Build and commit**

Run: `xcodebuild -scheme StableDiffusionApp -configuration Debug build 2>&1 | tail -5`

```bash
git add Sources/Views/Components/
git commit -m "feat: add SliderRow and PasteableTextField components"
```

---

### Task 4.2: Create SidebarView with Settings

**Files:**
- Create: `Sources/Views/SidebarView.swift`

**Step 1: Write SidebarView**

```swift
// Sources/Views/SidebarView.swift
import SwiftUI

@available(macOS 13.1, *)
struct SidebarView: View {
    @ObservedObject var viewModel: GenerationViewModel

    var body: some View {
        List {
            // Model Selection
            Section("Model") {
                ModelPickerRow(viewModel: viewModel)
            }

            // Generation Mode
            Section("Mode") {
                Picker("Mode", selection: $viewModel.isImg2ImgMode) {
                    Text("Text to Image").tag(false)
                    Text("Image to Image").tag(true)
                }
                .pickerStyle(.segmented)
                .help("Text-to-Image generates from scratch. Image-to-Image transforms an existing image.")

                if viewModel.isImg2ImgMode {
                    img2ImgSection
                }
            }

            // Prompts
            Section("Prompts") {
                PasteableTextField(
                    title: "Describe what you want...",
                    tooltip: "Enter your prompt - be descriptive for best results",
                    text: $viewModel.prompt
                )

                PasteableTextField(
                    title: "What to avoid (optional)...",
                    tooltip: "Describe what you DON'T want in the image",
                    text: $viewModel.negativePrompt
                )
            }

            // Basic Settings
            Section("Settings") {
                SliderRow(
                    title: "Steps",
                    tooltip: "More steps = better quality, slower generation (1-150)",
                    value: $viewModel.stepCount,
                    range: 1...150,
                    step: 1
                )

                SliderRow(
                    title: "Guidance",
                    tooltip: "How closely to follow the prompt (1-30, typical 7-15)",
                    value: $viewModel.guidanceScale,
                    range: 1...30,
                    step: 0.5
                )

                HStack {
                    Text("Seed")
                        .help("Same seed = same image for reproducibility")
                    Spacer()
                    Text("\(viewModel.seed)")
                        .monospacedDigit()
                    Button(action: { viewModel.randomizeSeed() }) {
                        Image(systemName: "dice")
                    }
                    .buttonStyle(.borderless)
                    .help("Generate random seed")
                }

                Stepper("Images: \(viewModel.imageCount)", value: $viewModel.imageCount, in: 1...4)
                    .help("Number of images to generate")
            }

            // Scheduler (collapsible)
            Section("Scheduler") {
                Picker("Type", selection: $viewModel.scheduler) {
                    ForEach(SchedulerType.allCases) { s in
                        Text(s.rawValue).tag(s)
                    }
                }
                .help(viewModel.scheduler.tooltip)

                Picker("Spacing", selection: $viewModel.timestepSpacing) {
                    ForEach(TimestepSpacing.allCases) { s in
                        Text(s.rawValue).tag(s)
                    }
                }
                .help(viewModel.timestepSpacing.tooltip)

                SliderRow(
                    title: "Shift",
                    tooltip: "Resolution-dependent shift (SD3/SDXL, 0-10)",
                    value: $viewModel.timestepShift,
                    range: 0...10
                )
            }

            // SDXL Options (only for SDXL/SD3)
            if viewModel.modelType.supportsSDXLOptions {
                Section("SDXL/SD3 Options") {
                    SliderRow(
                        title: "Original Size",
                        tooltip: "Original image size for micro-conditioning (256-2048)",
                        value: $viewModel.originalSize,
                        range: 256...2048
                    )

                    SliderRow(
                        title: "Target Size",
                        tooltip: "Target output size for micro-conditioning (256-2048)",
                        value: $viewModel.targetSize,
                        range: 256...2048
                    )

                    SliderRow(
                        title: "Aesthetic",
                        tooltip: "Quality hint (1-10, higher = prettier)",
                        value: $viewModel.aestheticScore,
                        range: 1...10
                    )
                }
            }

            // Compute
            Section("Compute") {
                Picker("Hardware", selection: $viewModel.computeUnit) {
                    ForEach(ComputeUnit.allCases) { u in
                        Text(u.rawValue).tag(u)
                    }
                }
                .help(viewModel.computeUnit.tooltip)

                Toggle("Reduce Memory", isOn: $viewModel.reduceMemory)
                    .help("Use less RAM (slightly slower)")
            }
        }
        .listStyle(.sidebar)
    }

    @ViewBuilder
    private var img2ImgSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            if let inputImage = viewModel.inputImage {
                Image(nsImage: inputImage)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(height: 100)
                    .cornerRadius(8)

                Button("Remove Image") {
                    viewModel.inputImage = nil
                }
                .buttonStyle(.bordered)
            } else {
                Button(action: selectInputImage) {
                    VStack {
                        Image(systemName: "photo.badge.plus")
                            .font(.system(size: 24))
                        Text("Select Image")
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: 80)
                    .background(Color.gray.opacity(0.2))
                    .cornerRadius(8)
                }
                .buttonStyle(.plain)
            }

            SliderRow(
                title: "Strength",
                tooltip: "How much to transform (0=none, 1=complete)",
                value: $viewModel.strength,
                range: 0...1,
                step: 0.05
            )
        }
    }

    private func selectInputImage() {
        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        panel.canChooseFiles = true
        panel.allowedContentTypes = [.image, .png, .jpeg, .heic]

        if panel.runModal() == .OK, let url = panel.url {
            if let image = NSImage(contentsOf: url) {
                // Resize to model output size
                let targetSize = viewModel.outputSize
                viewModel.inputImage = resizeImage(image, to: targetSize)
            }
        }
    }

    private func resizeImage(_ image: NSImage, to size: CGSize) -> NSImage {
        let newImage = NSImage(size: size)
        newImage.lockFocus()
        image.draw(in: NSRect(origin: .zero, size: size))
        newImage.unlockFocus()
        return newImage
    }
}
```

**Step 2: Write ModelPickerRow**

```swift
// Add to Sources/Views/SidebarView.swift or create separate file

@available(macOS 13.1, *)
struct ModelPickerRow: View {
    @ObservedObject var viewModel: GenerationViewModel

    var body: some View {
        HStack {
            Picker("Model", selection: $viewModel.selectedModel) {
                ForEach(viewModel.availableModels) { model in
                    HStack {
                        Text(model.name)
                        Spacer()
                        Text(model.type.outputSizeLabel)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .tag(model as ModelInfo?)
                }
            }
            .help("Select which Stable Diffusion model to use")

            Button(action: { Task { await viewModel.scanForModels() } }) {
                Image(systemName: "arrow.clockwise")
            }
            .buttonStyle(.borderless)
            .help("Rescan for models")
        }

        if let model = viewModel.selectedModel {
            HStack {
                Label(model.type.displayName, systemImage: "info.circle")
                    .font(.caption)
                    .foregroundColor(.secondary)
                Spacer()
                Text(model.type.outputSizeLabel)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
    }
}
```

**Step 3: Build and commit**

Run: `xcodebuild -scheme StableDiffusionApp -configuration Debug build 2>&1 | tail -10`

```bash
git add Sources/Views/SidebarView.swift
git commit -m "feat: add SidebarView with all settings and tooltips"
```

---

### Task 4.3: Create GenerationView and Progress Overlay

**Files:**
- Create: `Sources/Views/GenerationView.swift`
- Create: `Sources/Views/Components/ProgressOverlay.swift`

**Step 1: Write ProgressOverlay**

```swift
// Sources/Views/Components/ProgressOverlay.swift
import SwiftUI

@available(macOS 13.1, *)
struct ProgressOverlay: View {
    let progress: Float
    let stepCount: Int

    var body: some View {
        VStack(spacing: 16) {
            ProgressView(value: progress) {
                Text("Generating...")
                    .font(.headline)
            } currentValueLabel: {
                Text("\(Int(progress * 100))%")
                    .font(.system(.body, design: .monospaced))
            }
            .progressViewStyle(.linear)
            .frame(width: 200)

            Text("Step \(Int(progress * Float(stepCount))) of \(stepCount)")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding(24)
        .background(.regularMaterial)
        .cornerRadius(12)
        .shadow(radius: 8)
    }
}
```

**Step 2: Write GenerationView**

```swift
// Sources/Views/GenerationView.swift
import SwiftUI

@available(macOS 13.1, *)
struct GenerationView: View {
    @ObservedObject var viewModel: GenerationViewModel

    var body: some View {
        VStack(spacing: 0) {
            // Image Display Area
            ZStack {
                if let image = viewModel.generatedImage {
                    Image(nsImage: image)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .cornerRadius(8)
                        .shadow(radius: 4)

                    // Multi-image selector if more than one
                    if viewModel.generatedImages.count > 1 {
                        imageSelector
                            .frame(maxHeight: .infinity, alignment: .bottom)
                            .padding()
                    }
                } else {
                    emptyState
                }

                // Progress Overlay
                if viewModel.isGenerating {
                    ProgressOverlay(
                        progress: viewModel.progress,
                        stepCount: Int(viewModel.stepCount)
                    )
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color(nsColor: .textBackgroundColor))

            // Action Bar
            actionBar
                .padding()
                .background(Color(nsColor: .controlBackgroundColor))
        }

        // Error Display
        if let error = viewModel.errorMessage {
            HStack {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundColor(.red)
                Text(error)
                    .foregroundColor(.red)
                    .font(.caption)
                Spacer()
                Button("Dismiss") {
                    viewModel.errorMessage = nil
                }
                .buttonStyle(.borderless)
            }
            .padding()
            .background(Color.red.opacity(0.1))
        }
    }

    @ViewBuilder
    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "photo")
                .font(.system(size: 64))
                .foregroundColor(.secondary)

            Text("Enter a prompt and click Generate")
                .foregroundColor(.secondary)

            Text("Output: \(viewModel.modelType.outputSizeLabel)")
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }

    @ViewBuilder
    private var imageSelector: some View {
        HStack(spacing: 8) {
            ForEach(0..<viewModel.generatedImages.count, id: \.self) { index in
                Button(action: { viewModel.selectedImageIndex = index }) {
                    if let thumb = viewModel.generatedImages[index] {
                        Image(nsImage: thumb)
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .frame(width: 60, height: 60)
                            .cornerRadius(8)
                            .overlay(
                                RoundedRectangle(cornerRadius: 8)
                                    .stroke(viewModel.selectedImageIndex == index ? Color.accentColor : Color.clear, lineWidth: 2)
                            )
                    }
                }
                .buttonStyle(.plain)
            }
        }
        .padding(8)
        .background(.regularMaterial)
        .cornerRadius(12)
    }

    @ViewBuilder
    private var actionBar: some View {
        HStack {
            Button(action: { Task { await viewModel.generateImage() } }) {
                HStack {
                    if viewModel.isGenerating {
                        ProgressView()
                            .scaleEffect(0.8)
                        Text("Cancel")
                    } else {
                        Image(systemName: "play.fill")
                        Text(viewModel.isImg2ImgMode ? "Transform" : "Generate")
                    }
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .disabled(viewModel.prompt.isEmpty || viewModel.isGenerating || viewModel.selectedModel == nil)

            if viewModel.generatedImage != nil {
                Button(action: { saveImage(viewModel.generatedImage!) }) {
                    Label("Save", systemImage: "arrow.down.circle")
                }
                .buttonStyle(.bordered)

                Button(action: { shareImage(viewModel.generatedImage!) }) {
                    Label("Share", systemImage: "square.and.arrow.up")
                }
                .buttonStyle(.bordered)
            }
        }
    }

    private func saveImage(_ image: NSImage) {
        let panel = NSSavePanel()
        panel.nameFieldStringValue = "generated_\(viewModel.seed).png"
        panel.allowedContentTypes = [.png]

        if panel.runModal() == .OK, let url = panel.url,
           let cgImage = image.cgImage(forProposedRect: nil, context: nil, hints: nil) {
            let rep = NSBitmapImageRep(cgImage: cgImage)
            if let data = rep.representation(using: .png, properties: [:]) {
                try? data.write(to: url)
            }
        }
    }

    private func shareImage(_ image: NSImage) {
        guard let cgImage = image.cgImage(forProposedRect: nil, context: nil, hints: nil) else { return }
        let rep = NSBitmapImageRep(cgImage: cgImage)
        guard let data = rep.representation(using: .png, properties: [:]) else { return }

        let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent("shared_image.png")
        try? data.write(to: tempURL)

        let picker = NSSharingServicePicker(items: [tempURL])
        if let window = NSApp.keyWindow, let contentView = window.contentView {
            picker.show(relativeTo: .zero, of: contentView, preferredEdge: .minY)
        }
    }
}
```

**Step 3: Build and commit**

Run: `xcodebuild -scheme StableDiffusionApp -configuration Debug build 2>&1 | tail -10`

```bash
git add Sources/Views/GenerationView.swift Sources/Views/Components/ProgressOverlay.swift
git commit -m "feat: add GenerationView with progress overlay and multi-image support"
```

---

### Task 4.4: Update ContentView to Use New Architecture

**Files:**
- Modify: `Sources/ContentView.swift`

**Step 1: Replace ContentView with new structure**

```swift
// Sources/ContentView.swift
import SwiftUI

@available(macOS 13.1, *)
struct ContentView: View {
    @StateObject private var viewModel = GenerationViewModel()

    var body: some View {
        NavigationSplitView {
            SidebarView(viewModel: viewModel)
        } detail: {
            GenerationView(viewModel: viewModel)
        }
        .frame(minWidth: 900, minHeight: 600)
        .onAppear {
            Task {
                await viewModel.scanForModels()
                viewModel.randomizeSeed()
            }
        }
        .toolbar {
            ToolbarItemGroup {
                Text(viewModel.modelType.outputSizeLabel)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
    }
}

#if DEBUG
@available(macOS 13.1, *)
struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
#endif
```

**Step 2: Build and verify**

Run: `xcodebuild -scheme StableDiffusionApp -configuration Debug build 2>&1 | tail -20`

**Step 3: Commit**

```bash
git add Sources/ContentView.swift
git commit -m "feat: refactor ContentView to use MVVM architecture"
```

---

## Phase 5: Testing & Verification

### Task 5.1: Build and Run

**Step 1: Full clean build**

```bash
xcodebuild clean -scheme StableDiffusionApp
xcodebuild -scheme StableDiffusionApp -configuration Debug build
```

**Step 2: Run in Xcode**

```bash
open StableDiffusionApp.xcodeproj
```

Press Cmd+R to run.

**Step 3: Verify functionality**

- [ ] Model selector shows available models
- [ ] Settings have tooltips on hover
- [ ] Can paste text into prompt fields
- [ ] Progress updates during generation
- [ ] Can switch between models
- [ ] All sliders work within min/max ranges

**Step 4: Commit any fixes**

```bash
git add -A
git commit -m "fix: address any build or runtime issues"
```

---

## Summary

This plan creates a complete MVVM refactor with:

1. **Model Layer**: ModelType, ModelInfo, ModelRegistry, PipelineProvider, GenerationConfiguration
2. **ViewModel**: GenerationViewModel with all state and actions
3. **Views**: Modular components with tooltips, paste support, and progress overlay
4. **File Structure**: Clean separation of concerns

Each task is bite-sized (2-5 minutes) with exact code and verification steps.