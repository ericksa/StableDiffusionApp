import SwiftUI
import StableDiffusion
import CoreML

@available(macOS 13.1, *)
struct ContentView: View {
    @State private var prompt: String = ""
    @State private var generatedImage: NSImage?
    @State private var isGenerating: Bool = false
    @State private var progress: Double = 0
    @State private var errorMessage: String?
    @State private var seed: UInt32 = 0
    
    @State private var stepCount: Double = 20
    @State private var guidanceScale: Double = 7.5
    @State private var imageCount: Int = 1
    
    // Use bundled resources path
    private var modelPath: String {
        let path: String
        if let bundlePath = Bundle.main.resourcePath {
            path = bundlePath + "/StableDiffusionModels/original/compiled"
        } else {
            // Fallback for development
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
                VStack(alignment: .leading, spacing: 16) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Prompt")
                            .font(.headline)
                        TextField("Enter your prompt here...", text: $prompt)
                            .textFieldStyle(.roundedBorder)
                    }
                    
                    GroupBox("Settings") {
                        VStack(alignment: .leading, spacing: 12) {
                            HStack {
                                Text("Steps:")
                                Slider(value: $stepCount, in: 1...50, step: 1)
                                Text("\(Int(stepCount))")
                                    .frame(width: 30)
                            }
                            
                            HStack {
                                Text("Guidance:")
                                Slider(value: $guidanceScale, in: 1...20, step: 0.5)
                                Text(String(format: "%.1f", guidanceScale))
                                    .frame(width: 40)
                            }
                            
                            HStack {
                                Text("Seed:")
                                Text("\(seed)")
                                    .font(.system(.body, design: .monospaced))
                                Spacer()
                            }
                        }
                        .padding(8)
                    }
                    
                    Button(action: generateImage) {
                        HStack {
                            if isGenerating {
                                ProgressView()
                                    .scaleEffect(0.8)
                                Text("Generating... \(Int(progress * 100))%")
                            } else {
                                Image(systemName: "play.fill")
                                Text("Generate")
                            }
                        }
                        .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(prompt.isEmpty || isGenerating)
                    
                    if let error = errorMessage {
                        Text(error)
                            .foregroundColor(.red)
                            .font(.caption)
                            .padding()
                            .background(Color.red.opacity(0.1))
                            .cornerRadius(8)
                    }
                }
                .frame(width: 300)
                
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
    
    private func generateImage() {
        isGenerating = true
        errorMessage = nil
        progress = 0
        
        Task {
            do {
                print("Starting image generation...")
                print("Prompt: \(prompt)")
                print("Model path: \(modelPath)")
                
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
                pipelineConfig.negativePrompt = ""
                pipelineConfig.stepCount = Int(stepCount)
                pipelineConfig.seed = seed
                pipelineConfig.guidanceScale = Float(guidanceScale)
                
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
