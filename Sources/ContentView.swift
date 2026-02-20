import SwiftUI
import StableDiffusion
import CoreML
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
    @State private var imageCount: Int = 1
    @State private var isImg2Img: Bool = false
    
    // Use bundled resources path
    private var modelPath: String {
        let path: String
        if let bundlePath = Bundle.main.resourcePath {
            path = bundlePath + "/StableDiffusionModels/original/compiled"
        } else {
            path = "../StableDiffusionModels/original/compiled"
        }
        print("Model path: \(path)")
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
                            
                            Picker("", selection: $isImg2Img) {
                                Text("Text to Image").tag(false)
                                Text("Image to Image").tag(true)
                            }
                            .pickerStyle(.segmented)
                            .labelsHidden()
                            
                            if isImg2Img {
                                Text("Transform an existing image based on your prompt")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
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
                        .disabled(prompt.isEmpty || isGenerating || (isImg2Img && inputImage == nil))
                        
                        if let error = errorMessage {
                            Text(error)
                                .foregroundColor(.red)
                                .font(.caption)
                                .padding()
                                .background(Color.red.opacity(0.1))
                                .cornerRadius(8)
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
    
    private func regenerateSeed() {
        seed = UInt32.random(in: 0...UInt32.max)
    }
    
    private func selectImage() {
        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        panel.canChooseFiles = true
        panel.allowedContentTypes = [.image, .png, .jpeg, .heic]
        
        if panel.runModal() == .OK, let url = panel.url {
            if let image = NSImage(contentsOf: url) {
                inputImage = image
            }
        }
    }
    
    private func generateImage() {
        isGenerating = true
        errorMessage = nil
        progress = 0
        
        Task {
            do {
                print("Starting generation...")
                print("Prompt: \(prompt)")
                print("Negative: \(negativePrompt)")
                print("Mode: \(isImg2Img ? "img2img" : "txt2img")")
                print("Steps: \(Int(stepCount)), Guidance: \(guidanceScale)")
                
                var config = MLModelConfiguration()
                config.computeUnits = .cpuAndGPU
                
                print("Creating pipeline...")
                let pipeline = try StableDiffusionPipeline(
                    resourcesAt: URL(fileURLWithPath: modelPath),
                    controlNet: [],
                    configuration: config,
                    disableSafety: false,
                    reduceMemory: true
                )
                
                print("Loading resources...")
                try pipeline.loadResources()
                print("Resources loaded!")
                
                var pipelineConfig = StableDiffusionPipeline.Configuration(prompt: prompt)
                pipelineConfig.negativePrompt = negativePrompt
                pipelineConfig.stepCount = Int(stepCount)
                pipelineConfig.seed = seed
                pipelineConfig.guidanceScale = Float(guidanceScale)
                
                // Set img2img mode
                if isImg2Img, let nsImage = inputImage {
                    pipelineConfig.strength = Float(strength)
                    
                    if let cgImage = nsImage.cgImage(forProposedRect: nil, context: nil, hints: nil) {
                        pipelineConfig.startingImage = cgImage
                    }
                }
                
                print("Starting generation with \(Int(stepCount)) steps...")
                let images = try await pipeline.generateImages(
                    configuration: pipelineConfig,
                    progressHandler: { progress in
                        print("Step \(progress.step)/\(progress.stepCount)")
                        self.progress = Double(progress.step) / Double(progress.stepCount)
                        return true
                    }
                )
                
                print("Generation complete! Images: \(images.count)")
                
                if let cgImage = images.first ?? nil {
                    let nsImage = NSImage(cgImage: cgImage, size: NSSize(width: cgImage.width, height: cgImage.height))
                    await MainActor.run {
                        self.generatedImage = nsImage
                        self.isGenerating = false
                    }
                } else {
                    await MainActor.run {
                        self.errorMessage = "No image generated"
                        self.isGenerating = false
                    }
                }
            } catch {
                print("ERROR: \(error)")
                await MainActor.run {
                    self.errorMessage = error.localizedDescription
                    self.isGenerating = false
                }
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
