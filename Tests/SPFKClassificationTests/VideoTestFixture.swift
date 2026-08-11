// Copyright Ryan Francesconi. All Rights Reserved. Revision History at https://github.com/ryanfrancesconi/spfk-classification

import AVFoundation
import CoreGraphics
import Foundation
import ImageIO
import SPFKBase

// MARK: - Synthetic multi-segment video fixture for tests

/// Builds a video (no audio track) from a sequence of still images, each held for a fixed
/// duration -- mirroring `spfk-video`'s own `VideoTestFixture` approach (a procedurally
/// generated fixture rather than a bundled binary asset) but using real photos as segment
/// content instead of solid colors, so each segment produces genuinely distinct Vision
/// classifications rather than just different pixel values.
enum VideoTestFixture {
    /// Generates a synthetic H.264 MP4 with no audio track, showing each image in `segments`
    /// for `segmentDuration` seconds in sequence.
    ///
    /// - Parameters:
    ///   - segments: Images to show, in order. Each is stretched to fill `size`.
    ///   - segmentDuration: How long each image is shown, in seconds.
    ///   - size: Output frame dimensions. Must be even values for H.264 encoding.
    /// - Returns: A file URL to the generated video. Call sites are responsible for cleaning
    ///   it up with `FileManager.removeItem`.
    static func makeMultiSegmentTestVideo(
        segments: [CGImage],
        segmentDuration: TimeInterval,
        size: CGSize = CGSize(width: 640, height: 360)
    ) async throws -> URL {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString + ".mp4")

        let writer = try AVAssetWriter(outputURL: url, fileType: .mp4)

        let videoSettings: [String: Any] = [
            AVVideoCodecKey: AVVideoCodecType.h264,
            AVVideoWidthKey: Int(size.width),
            AVVideoHeightKey: Int(size.height),
        ]
        let writerInput = AVAssetWriterInput(mediaType: .video, outputSettings: videoSettings)
        writerInput.expectsMediaDataInRealTime = false

        let pixelBufferAttrs: [String: Any] = [
            kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32ARGB,
            kCVPixelBufferWidthKey as String: Int(size.width),
            kCVPixelBufferHeightKey as String: Int(size.height),
        ]
        let adaptor = AVAssetWriterInputPixelBufferAdaptor(
            assetWriterInput: writerInput,
            sourcePixelBufferAttributes: pixelBufferAttrs
        )

        writer.add(writerInput)
        writer.startWriting()
        writer.startSession(atSourceTime: .zero)

        let frameRate = 10
        let timescale: CMTimeScale = 600
        let framesPerSegment = Int(segmentDuration) * frameRate

        var frameIndex = 0

        for image in segments {
            for _ in 0..<framesPerSegment {
                while !writerInput.isReadyForMoreMediaData {
                    await Task.yield()
                }

                let presentationTime = CMTime(
                    value: CMTimeValue(frameIndex * Int(timescale) / frameRate),
                    timescale: timescale
                )

                guard let pool = adaptor.pixelBufferPool else { break }
                var pixelBuffer: CVPixelBuffer?
                guard CVPixelBufferPoolCreatePixelBuffer(kCFAllocatorDefault, pool, &pixelBuffer) == kCVReturnSuccess,
                      let pixelBuffer
                else { break }

                fill(pixelBuffer, with: image)
                adaptor.append(pixelBuffer, withPresentationTime: presentationTime)

                frameIndex += 1
            }
        }

        writerInput.markAsFinished()

        await withCheckedContinuation { continuation in
            writer.finishWriting { continuation.resume() }
        }

        if let error = writer.error {
            throw error
        }

        return url
    }

    /// Loads a JPEG/HEIC/etc. fixture file as a `CGImage` for use as a video segment's content.
    static func loadImage(at url: URL) throws -> CGImage {
        guard let source = CGImageSourceCreateWithURL(url as CFURL, nil),
              let image = CGImageSourceCreateImageAtIndex(source, 0, nil)
        else {
            throw NSError(description: "Could not load image at \(url.path)")
        }
        return image
    }

    private static func fill(_ buffer: CVPixelBuffer, with image: CGImage) {
        CVPixelBufferLockBaseAddress(buffer, [])
        defer { CVPixelBufferUnlockBaseAddress(buffer, []) }

        let width = CVPixelBufferGetWidth(buffer)
        let height = CVPixelBufferGetHeight(buffer)
        let bytesPerRow = CVPixelBufferGetBytesPerRow(buffer)
        guard let baseAddress = CVPixelBufferGetBaseAddress(buffer) else { return }

        guard let context = CGContext(
            data: baseAddress,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: bytesPerRow,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedFirst.rawValue
        ) else { return }

        // Stretch-to-fill: the test only needs each segment's content to remain recognizable
        // to Vision, not aspect-correct.
        context.draw(image, in: CGRect(x: 0, y: 0, width: CGFloat(width), height: CGFloat(height)))
    }
}
