import CoreGraphics
import CoreML
import StableDiffusion
import SwiftUI
import UniformTypeIdentifiers

@available(macOS 13.1, *)
struct ContentView: View {
    @State private var prompt: String = ""
    @State private var negativePrompt: String = ""
    @State private var generatedImage: NSImage?
    @State private var inputImage: NSImage?
    @State private var isGenerating: Bool = false
    @State private var progress: Double = 0
    @State private var errorMessage: String?
    @State private var seed: UInt32 = 0

    @State private var stepCount: Double = 40
    @State private var guidanceScale: Double = 15.0
    @State private var strength: Double = 0.5
    @State private var isImg2Img: Bool = false

    // Use bundled resources path
    private var modelPath: String {
        let path: String

        // First, check if models exist in the app bundle (for released app)
        if let bundlePath = Bundle.main.resourcePath {
            let bundleModelsPath = bundlePath + "/StableDiffusionModels/original/compiled"
            if FileManager.default.fileExists(atPath: bundleModelsPath) {
                print("Using bundle model path: \(bundleModelsPath)")
                path = bundleModelsPath
                return path
            }
        }

        // For Xcode development, check the project Resources directory
        let fileManager = FileManager.default
        let currentDirectory = fileManager.currentDirectoryPath

        // Try multiple possible project locations
        let possiblePaths = [
            currentDirectory + "/Resources/StableDiffusionModels/original/compiled",
            currentDirectory + "/../Resources/StableDiffusionModels/original/compiled",
            "/Users/adamerickson/Projects/stable/StableDiffusionApp/Resources/StableDiffusionModels/original/compiled",
            "../Resources/StableDiffusionModels/original/compiled",
        ]

        for potentialPath in possiblePaths {
            if fileManager.fileExists(atPath: potentialPath) {
                print("Using project model path: \(potentialPath)")
                path = potentialPath
                return path
            }
        }

        // Final fallback
        print("WARNING: Model not found at any expected path, using fallback")
        path = "../StableDiffusionModels/original/compiled"
        return path
    }

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("Stable Diffusion")
                    .font(.title)
                    .fontWeight(.bold)
                Spacer()
                Button(action: regenerateSeed) {
                    Label("New Seed", systemImage: "dice")
                }
                .buttonStyle(.borderless)
            }
            .padding()
            .background(Color(nsColor: .controlBackgroundColor))

            Divider()

            // Main content
            HStack(spacing: 20) {
                // Left panel - Settings
                ScrollView {
                    VStack(alignment: .leading, spacing: 20) {
                        // Generation Mode
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Generation Mode")
                                .font(.headline)
                                .foregroundColor(.primary)

                            VStack(alignment: .leading, spacing: 8) {
                                Picker("", selection: $isImg2Img) {
                                    Text("Text to Image").tag(false)
                                    Text("Image to Image").tag(true)
                                }
                                .pickerStyle(.segmented)
                                .labelsHidden()

                                if isImg2Img {
                                    Text(
                                        "Transform an existing image based on your prompt. Select an image and adjust the strength slider."
                                    )
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                    .multilineTextAlignment(.leading)
                                } else {
                                    Text(
                                        "Generate a new image from your text prompt. The more detailed your description, the better the result."
                                    )
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                    .multilineTextAlignment(.leading)
                                }
                            }
                        }
                        .padding()
                        .background(Color(nsColor: .controlBackgroundColor))
                        .cornerRadius(8)

                        // Image input for img2img
                        if isImg2Img {
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Input Image")
                                    .font(.headline)

                                if let image = inputImage {
                                    Image(nsImage: image)
                                        .resizable()
                                        .aspectRatio(contentMode: .fit)
                                        .frame(height: 120)
                                        .cornerRadius(8)

                                    Button("Remove Image") {
                                        inputImage = nil
                                    }
                                    .buttonStyle(.bordered)
                                } else {
                                    Button(action: selectImage) {
                                        VStack {
                                            Image(systemName: "photo.badge.plus")
                                                .font(.system(size: 32))
                                            Text("Select Image")
                                        }
                                        .frame(maxWidth: .infinity)
                                        .frame(height: 120)
                                        .background(Color.gray.opacity(0.2))
                                        .cornerRadius(8)
                                    }
                                    .buttonStyle(.plain)
                                }

                                // Strength slider
                                VStack(alignment: .leading, spacing: 4) {
                                    HStack {
                                        Text("Strength:")
                                        Slider(value: $strength, in: 0...1, step: 0.05)
                                        Text(String(format: "%.2f", strength))
                                            .frame(width: 40)
                                    }
                                    Text("Higher = more transformation")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                            }
                            .padding()
                            .background(Color(nsColor: .controlBackgroundColor))
                            .cornerRadius(8)
                        }

                        // Prompt
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Prompt")
                                .font(.headline)
                            TextField("What you want to see...", text: $prompt)
                                .textFieldStyle(.roundedBorder)
                        }

                        // Negative Prompt
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Negative Prompt")
                                .font(.headline)
                            TextField("What to avoid (optional)...", text: $negativePrompt)
                                .textFieldStyle(.roundedBorder)
                        }

                        // Settings
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Settings")
                                .font(.headline)

                            HStack {
                                Text("Steps:")
                                Slider(value: $stepCount, in: 1...50, step: 1)
                                Text("\(Int(stepCount))")
                                    .frame(width: 30)
                                    .font(.system(.body, design: .monospaced))
                            }

                            HStack {
                                Text("Guidance:")
                                Slider(value: $guidanceScale, in: 1...20, step: 0.5)
                                Text(String(format: "%.1f", guidanceScale))
                                    .frame(width: 40)
                                    .font(.system(.body, design: .monospaced))
                            }

                            HStack {
                                Text("Seed:")
                                Text("\(seed)")
                                    .font(.system(.body, design: .monospaced))
                                Spacer()
                            }
                        }
                        .padding()
                        .background(Color(nsColor: .controlBackgroundColor))
                        .cornerRadius(8)

                        // Generate Button
                        Button(action: generateImage) {
                            HStack {
                                if isGenerating {
                                    ProgressView()
                                        .scaleEffect(0.8)
                                    Text("Generating... \(Int(progress * 100))%")
                                } else {
                                    Image(systemName: "play.fill")
                                    Text(isImg2Img ? "Transform" : "Generate")
                                }
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 8)
                        }
                        .buttonStyle(.borderedProminent)
                        .controlSize(.large)
                        .disabled(
                            prompt.isEmpty || isGenerating || (isImg2Img && inputImage == nil))

                        if let error = errorMessage {
                            Text(error)
                                .foregroundColor(.red)
                                .font(.caption)
                                .padding()
                                .background(Color.red.opacity(0.1))
                                .cornerRadius(8)
                        }

                        // Download and share buttons
                        if let generatedImage = generatedImage {
                            HStack(spacing: 12) {
                                Button(action: { saveImage(generatedImage) }) {
                                    Label("Download", systemImage: "arrow.down.circle")
                                }
                                .buttonStyle(.bordered)

                                Button(action: { shareImage(generatedImage) }) {
                                    Label("Share", systemImage: "square.and.arrow.up")
                                }
                                .buttonStyle(.bordered)
                            }
                            .padding(.top, 8)
                        }
                    }
                    .padding()
                }
                .frame(width: 340)

                // Right panel - Image
                VStack {
                    if let image = generatedImage {
                        Image(nsImage: image)
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .cornerRadius(8)
                            .shadow(radius: 4)
                    } else {
                        VStack {
                            Image(systemName: "photo")
                                .font(.system(size: 64))
                                .foregroundColor(.secondary)
                            Text("Enter a prompt and click Generate")
                                .foregroundColor(.secondary)
                        }
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                    }
                }
                .background(Color(nsColor: .textBackgroundColor))
                .cornerRadius(12)
            }
            .padding()
        }
        .onAppear {
            regenerateSeed()
        }
    }

    // MARK: - Private Methods

    private func regenerateSeed() {
        seed = UInt32.random(in: 0...UInt32.max)
    }

    private func selectImage() {
        print("Opening file selection...")

        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        panel.canChooseFiles = true
        panel.allowedContentTypes = [.image, .png, .jpeg, .heic]
        panel.title = "Select an Image"
        panel.prompt = "Choose"
        panel.directoryURL =
            URL(fileURLWithPath: "~/Pictures", isDirectory: true).standardizedFileURL

        let result = panel.runModal()
        print("Selection result: \(result.rawValue)")

        if result == .OK, let url = panel.url {
            print("Selected: \(url.path)")

            if let image = NSImage(contentsOf: url) {
                print("Original image size: \(image.size)")

                // Create a properly sized 512x512 CGImage
                let targetSize = CGSize(width: 512, height: 512)
                guard let resizedCGImage = createResizedCGImage(from: image, targetSize: targetSize) else {
                    errorMessage = "Could not resize the image to 512x512"
                    return
                }

                print("Resized CGImage: \(resizedCGImage.width)x\(resizedCGImage.height)")
                let resizedNSImage = NSImage(cgImage: resizedCGImage, size: NSSize(width: 512, height: 512))
                inputImage = resizedNSImage
            } else {
                errorMessage = "Failed to load image from \(url.path)"
            }
        }
    }

    /// Creates a properly resized CGImage at exactly the target dimensions
    private func createResizedCGImage(from nsImage: NSImage, targetSize: CGSize) -> CGImage? {
        guard let cgImage = nsImage.cgImage(forProposedRect: nil, context: nil, hints: nil) else {
            print("Failed to get CGImage from NSImage")
            return nil
        }

        let width = Int(targetSize.width)
        let height = Int(targetSize.height)

        // Create a CGContext with the exact target dimensions
        guard let colorSpace = CGColorSpace(name: CGColorSpace.sRGB) else {
            print("Failed to create color space")
            return nil
        }

        guard let context = CGContext(
            data: nil,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: width * 4,
            space: colorSpace,
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else {
            print("Failed to create CGContext")
            return nil
        }

        // Draw the image scaled to exactly fit the context
        context.interpolationQuality = .high
        context.draw(cgImage, in: CGRect(x: 0, y: 0, width: width, height: height))

        guard let resizedImage = context.makeImage() else {
            print("Failed to create resized CGImage")
            return nil
        }

        return resizedImage
    }

    private func generateImage() {
        isGenerating = true
        errorMessage = nil
        progress = 0

        Task {
            do {
                print("=== Starting Generation ===")
                print("Prompt: \(prompt)")
                print("Negative: \(negativePrompt)")
                print("Mode: \(isImg2Img ? "img2img" : "txt2img")")
                print("Steps: \(Int(stepCount)), Guidance: \(guidanceScale), Seed: \(seed)")

                // IMPORTANT: Use CPU only to avoid expensive GPU/ANE shader compilation
                // GPU compilation can take 30+ minutes and causes the disk write issues
                // CPU inference is slower but loads instantly and uses much less memory
                let config = MLModelConfiguration()
                config.computeUnits = .cpuOnly

                // Verify model path exists
                let modelURL = URL(fileURLWithPath: modelPath)
                guard FileManager.default.fileExists(atPath: modelURL.path) else {
                    throw NSError(
                        domain: "ModelError", code: 1001,
                        userInfo: [NSLocalizedDescriptionKey: "Model not found at: \(modelPath)"])
                }

                print("Loading pipeline from: \(modelURL.path)")
                print("Using CPU-only mode for faster loading")

                print("Creating pipeline...")
                let pipeline = try StableDiffusionPipeline(
                    resourcesAt: modelURL,
                    controlNet: [],
                    configuration: config,
                    disableSafety: true,
                    reduceMemory: true
                )

                print("Loading resources...")
                try pipeline.loadResources()
                print("Resources loaded")

                var pipelineConfig = StableDiffusionPipeline.Configuration(prompt: prompt)
                pipelineConfig.negativePrompt = negativePrompt
                pipelineConfig.stepCount = Int(stepCount)
                pipelineConfig.seed = seed
                pipelineConfig.guidanceScale = Float(guidanceScale)

                if isImg2Img, let nsImage = inputImage {
                    // Get the actual NSImage size
                    print("NSImage size: \(nsImage.size)")

                    guard let cgImage = nsImage.cgImage(forProposedRect: nil, context: nil, hints: nil) else {
                        await MainActor.run {
                            self.errorMessage = "Failed to convert NSImage to CGImage"
                            self.isGenerating = false
                        }
                        return
                    }

                    pipelineConfig.strength = Float(strength)
                    pipelineConfig.startingImage = cgImage
                    print("=== Img2Img Debug ===")
                    print("Input CGImage dimensions: \(cgImage.width)x\(cgImage.height)")
                    print("CGImage bitsPerPixel: \(cgImage.bitsPerPixel), bitsPerComponent: \(cgImage.bitsPerComponent)")
                    print("CGImage colorSpace: \(String(describing: cgImage.colorSpace?.name))")
                    print("Expected encoder shape: [1, 3, 512, 512]")

                    // Verify dimensions match expected 512x512
                    if cgImage.width != 512 || cgImage.height != 512 {
                        print("ERROR: CGImage dimensions don't match expected 512x512!")
                        await MainActor.run {
                            self.errorMessage = "Image dimensions must be 512x512, got \(cgImage.width)x\(cgImage.height)"
                            self.isGenerating = false
                        }
                        return
                    }
                }

                print("Generating...")
                let images = try pipeline.generateImages(
                    configuration: pipelineConfig,
                    progressHandler: { progress in
                        DispatchQueue.main.async {
                            self.progress = Double(progress.step) / Double(progress.stepCount)
                        }
                        return true
                    }
                )

                print("Generation complete. Images: \(images.count)")

                await MainActor.run {
                    if let cgImage = images.first ?? nil {
                        self.generatedImage = NSImage(
                            cgImage: cgImage,
                            size: NSSize(width: cgImage.width, height: cgImage.height))
                    } else {
                        self.errorMessage = "No image generated"
                    }
                    self.isGenerating = false
                    self.progress = 1.0
                }

            } catch {
                print("ERROR: \(error)")
                await MainActor.run {
                    self.errorMessage = "Generation failed: \(error.localizedDescription)"
                    self.isGenerating = false
                }
            }
        }
    }

    private func saveImage(_ image: NSImage) {
        let panel = NSSavePanel()
        panel.nameFieldStringValue = "generated_image_\(seed).png"
        panel.allowedContentTypes = [.png]
        panel.canCreateDirectories = true

        if panel.runModal() == .OK, let url = panel.url {
            guard let cgImage = image.cgImage(forProposedRect: nil, context: nil, hints: nil) else {
                errorMessage = "Could not save image"
                return
            }
            let rep = NSBitmapImageRep(cgImage: cgImage)
            guard let data = rep.representation(using: .png, properties: [:]) else {
                errorMessage = "Could not create PNG data"
                return
            }

            do {
                try data.write(to: url)
                print("Saved to: \(url.path)")
            } catch {
                errorMessage = "Failed to save: \(error.localizedDescription)"
            }
        }
    }

    private func shareImage(_ image: NSImage) {
        guard let cgImage = image.cgImage(forProposedRect: nil, context: nil, hints: nil) else {
            errorMessage = "Could not share image"
            return
        }
        let rep = NSBitmapImageRep(cgImage: cgImage)
        guard let data = rep.representation(using: .png, properties: [:]) else {
            errorMessage = "Could not create PNG data"
            return
        }

        let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent(
            "shared_image.png")
        do {
            try data.write(to: tempURL)
            let sharingPicker = NSSharingServicePicker(items: [tempURL])
            if let window = NSApp.keyWindow, let contentView = window.contentView {
                sharingPicker.show(relativeTo: .zero, of: contentView, preferredEdge: .minY)
            }
        } catch {
            errorMessage = "Failed to share: \(error.localizedDescription)"
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

