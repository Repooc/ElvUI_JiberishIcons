// Extract foreground masks locally with macOS Vision. Preserve source colors.
// swiftc -module-cache-path /tmp/fabled-swift-cache tools/foreground-fabled.swift -o /tmp/fabled-foreground
// /tmp/fabled-foreground input.png output.png [input.png output.png ...]
import Foundation
import Vision
import CoreImage
import ImageIO

let args = Array(CommandLine.arguments.dropFirst())
guard !args.isEmpty && args.count % 2 == 0 else {
    fatalError("Pass input/output PNG pairs")
}
let context = CIContext(options: [.cacheIntermediates: false])
for index in stride(from: 0, to: args.count, by: 2) {
    try autoreleasepool {
        let input = URL(fileURLWithPath: args[index])
        let output = URL(fileURLWithPath: args[index + 1])
        let handler = VNImageRequestHandler(url: input)
        let request = VNGenerateForegroundInstanceMaskRequest()
        try handler.perform([request])
        guard let observation = request.results?.first, !observation.allInstances.isEmpty,
              let original = CIImage(contentsOf: input) else {
            fatalError("No foreground found: \(input.lastPathComponent)")
        }
        let maskBuffer = try observation.generateScaledMaskForImage(forInstances: observation.allInstances, from: handler)
        let mask = CIImage(cvPixelBuffer: maskBuffer)
        let empty = CIImage(color: .clear).cropped(to: original.extent)
        let cutout = original.applyingFilter("CIBlendWithMask", parameters: [
            kCIInputBackgroundImageKey: empty, kCIInputMaskImageKey: mask
        ])
        try context.writePNGRepresentation(of: cutout, to: output, format: .RGBA8,
                                           colorSpace: CGColorSpace(name: CGColorSpace.sRGB)!)
        print("\(input.lastPathComponent): \(observation.allInstances.count) foreground instance(s)")
    }
}
