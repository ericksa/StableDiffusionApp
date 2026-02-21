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