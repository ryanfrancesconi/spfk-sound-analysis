// Copyright Ryan Francesconi. All Rights Reserved. Revision History at https://github.com/ryanfrancesconi/spfk-classification

import CoreGraphics
import CoreML
import Foundation
import SPFKVideo
import Vision

public enum ImageClassification {
    /// Default minimum confidence. Measured against real `VNClassifyImageRequest` output; the
    /// sound classifier's default does not transfer, the two being calibrated independently.
    public static let defaultConfidence: Double = 0.6

    /// The identifiers Vision's built-in classifier can currently produce (1303 as of this
    /// writing -- confirmed against real framework output, not a fixed/guessed count).
    public static func knownClassifications() throws -> [String] {
        try VNClassifyImageRequest().supportedIdentifiers()
    }

    /// Classifies the image at `url` using Vision's built-in image classifier.
    ///
    ///
    /// - Parameters:
    ///   - url: Location of the image to classify. Any format supported by ImageIO.
    ///   - minimumConfidence: Classifications below this confidence are excluded from the result.
    /// - Returns: The image's classifications at or above `minimumConfidence`, or `nil` if
    ///   Vision produced no result set at all.
    /// - Throws: If the image cannot be loaded/decoded, or the request otherwise fails.
    public static func analyze(
        url: URL,
        minimumConfidence: Double = defaultConfidence
    ) async throws -> [VNClassificationObservation]? {
        try Task.checkCancellation()

        let handler = VNImageRequestHandler(url: url, options: [:])
        return try classify(with: handler, minimumConfidence: minimumConfidence)
    }

    /// Classifies an in-memory image using Vision's built-in image classifier.
    ///
    /// For a caller that already has a decoded image rather than a file.
    ///
    /// - Parameters:
    ///   - cgImage: The image to classify.
    ///   - minimumConfidence: Classifications below this confidence are excluded from the result.
    /// - Returns: The image's classifications at or above `minimumConfidence`, or `nil` if
    ///   Vision produced no result set at all.
    /// - Throws: If the request otherwise fails.
    public static func analyze(
        cgImage: CGImage,
        minimumConfidence: Double = defaultConfidence
    ) async throws -> [VNClassificationObservation]? {
        try Task.checkCancellation()

        let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
        return try classify(with: handler, minimumConfidence: minimumConfidence)
    }

    private static func classify(
        with handler: VNImageRequestHandler,
        minimumConfidence: Double
    ) throws -> [VNClassificationObservation]? {
        let request = VNClassifyImageRequest()
        try handler.perform([request])

        guard let results = request.results else {
            return nil
        }

        return results.filter { $0.confidence >= Float(minimumConfidence) }
    }

    /// Classifies the image at `url` using a caller-supplied Core ML image-classification
    /// model instead of Vision's built-in classifier -- the same escape hatch
    /// `SoundClassification.analyze(using:)` provides for custom `SoundAnalysis` models.
    ///
    /// Narrowed to `VNClassificationObservation`, so a model backing any other observation kind
    /// produces an empty result rather than an error.
    ///
    /// - Parameters:
    ///   - mlModel: A Core ML model that takes an image input and produces classifications.
    ///   - url: Location of the image to classify. Any format supported by ImageIO.
    ///   - minimumConfidence: Classifications below this confidence are excluded from the result.
    /// - Returns: The image's classifications at or above `minimumConfidence`, or `nil` if
    ///   Vision produced no result set at all.
    /// - Throws: If `mlModel` isn't a supported Vision model, the image can't be loaded/decoded,
    ///   or the request otherwise fails.
    public static func analyze(
        using mlModel: MLModel,
        url: URL,
        minimumConfidence: Double = defaultConfidence
    ) async throws -> [VNClassificationObservation]? {
        try Task.checkCancellation()

        let coreMLModel = try VNCoreMLModel(for: mlModel)
        let request = VNCoreMLRequest(model: coreMLModel)

        let handler = VNImageRequestHandler(url: url, options: [:])
        try handler.perform([request])

        guard let results = request.results else {
            return nil
        }

        return results
            .compactMap { $0 as? VNClassificationObservation }
            .filter { $0.confidence >= Float(minimumConfidence) }
    }

    /// How `analyzeVideo` chooses which timestamps to sample from a video's duration.
    ///
    /// A type rather than a bare interval so a smarter mode can arrive as a case. Fixed intervals
    /// are what scene-detection pipelines fall back to for long content anyway.
    public enum SamplingStrategy: Sendable {
        /// Sample one frame every `step` seconds, starting at 0.
        case fixedInterval(step: TimeInterval)
    }

    /// Larger than a scrubber thumbnail: the classifier needs more detail than the screen does.
    private static let frameClassificationSize = CGSize(width: 640, height: 640)

    /// Classifies a video's visual content by sampling still frames and aggregating
    /// classifications across them.
    ///
    /// Vision classifies stills only, so this samples frames and aggregates. **No frame-count cap
    /// is enforced**: one classification call per sampled frame, so a caller exposing the interval
    /// has to bound the cost itself.
    ///
    /// - Parameters:
    ///   - url: File URL of the video asset.
    ///   - sampling: How frames are chosen from the video's duration.
    ///   - minimumConfidence: Classifications below this confidence are excluded from the result.
    /// - Returns: Classifications aggregated across all sampled frames -- the highest
    ///   confidence seen for each identifier, at or above `minimumConfidence`, sorted by
    ///   descending confidence. `nil` if no frames could be sampled or classified.
    /// - Throws: If the sampling step isn't positive, the video asset isn't playable or has no
    ///   video track, or classification itself fails.
    public static func analyzeVideo(
        url: URL,
        sampling: SamplingStrategy,
        minimumConfidence: Double = defaultConfidence
    ) async throws -> [VNClassificationObservation]? {
        let timestamps = try await sampleTimestamps(for: url, sampling: sampling)
        guard !timestamps.isEmpty else { return nil }

        let frames = try await VideoFrameExtractor.frames(
            from: url,
            at: timestamps,
            maximumSize: frameClassificationSize
        )
        guard !frames.isEmpty else { return nil }

        // VNClassificationObservation isn't Sendable, so frames are classified sequentially
        // rather than concurrently -- it can't cross a task-group boundary.
        var perFrameResults: [VNClassificationObservation] = []
        for (_, image) in frames {
            let frameResult = try await analyze(cgImage: image, minimumConfidence: minimumConfidence) ?? []
            perFrameResults.append(contentsOf: frameResult)
        }

        guard !perFrameResults.isEmpty else { return nil }

        return aggregate(perFrameResults)
    }

    private static func sampleTimestamps(
        for url: URL,
        sampling: SamplingStrategy
    ) async throws -> [TimeInterval] {
        switch sampling {
        case let .fixedInterval(step):
            guard step > 0 else {
                throw ImageClassificationError.invalidSamplingStep(step)
            }

            let duration = try await VideoFrameExtractor.duration(of: url)
            return Array(stride(from: 0, to: duration, by: step))
        }
    }

    /// Best confidence per identifier, sorted descending. Not shared with
    /// `SoundClassificationResultObserver`'s equivalent: the two observation types share no
    /// protocol, and their confidences are different widths (`VNConfidence` is `Float`,
    /// `SNClassification.confidence` is `Double`).
    private static func aggregate(
        _ observations: [VNClassificationObservation]
    ) -> [VNClassificationObservation] {
        var bestByIdentifier: [String: VNClassificationObservation] = [:]

        for observation in observations {
            let identifier = observation.identifier

            if let existing = bestByIdentifier[identifier] {
                if observation.confidence > existing.confidence {
                    bestByIdentifier[identifier] = observation
                }
            } else {
                bestByIdentifier[identifier] = observation
            }
        }

        return bestByIdentifier.values.sorted { $0.confidence > $1.confidence }
    }
}

public enum ImageClassificationError: Error {
    case invalidSamplingStep(TimeInterval)
}
