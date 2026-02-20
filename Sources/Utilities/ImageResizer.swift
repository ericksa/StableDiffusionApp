import AppKit
import CoreGraphics
import Foundation

class ImageResizer {

    /// Resizes an NSImage to the specified size while maintaining aspect ratio
    /// - Parameters:
    ///   - image: The image to resize
    ///   - targetSize: The target size (e.g., 512x512)
    /// - Returns: Resized NSImage
    static func resizeImage(_ image: NSImage, to targetSize: CGSize) -> NSImage {
        let newImage = NSImage(size: targetSize)

        newImage.lockFocus()

        image.draw(
            in: NSRect(origin: .zero, size: targetSize),
            from: NSRect(origin: .zero, size: image.size),
            operation: .copy,
            fraction: 1.0
        )

        newImage.unlockFocus()

        return newImage
    }

    /// Gets the expected image size based on the model
    /// - Parameter modelPath: Path to the model
    /// - Returns: Expected CGSize (default 512x512)
    static func getExpectedImageSize(for modelPath: String) -> CGSize {
        // Detect model version from path or configuration
        if modelPath.contains("2.0") || modelPath.contains("2-1") {
            return CGSize(width: 768, height: 768)
        }
        return CGSize(width: 512, height: 512)
    }

    /// Prepares an image for img2img by resizing if needed
    /// - Parameters:
    ///   - image: Input image
    ///   - modelPath: Path to the model
    /// - Returns: Properly sized NSImage for the model
    static func prepareImageForStableDiffusion(_ image: NSImage, modelPath: String) -> NSImage {
        let expectedSize = getExpectedImageSize(for: modelPath)

        // Check if resizing is needed
        if abs(image.size.width - expectedSize.width) > 1
            || abs(image.size.height - expectedSize.height) > 1
        {
            print("Resizing image from \(image.size) to \(expectedSize)")
            return resizeImage(image, to: expectedSize)
        }

        return image
    }
}
