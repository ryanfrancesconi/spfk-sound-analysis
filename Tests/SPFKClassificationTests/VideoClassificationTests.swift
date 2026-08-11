import Foundation
import SPFKBase
@testable import SPFKClassification
import SPFKTesting
import Testing
import Vision

@Suite(.tags(.file))
final class VideoClassificationTests: TestCaseModel {
    /// A video with two segments of real, visually distinct content and no audio track --
    /// proving both that `analyzeVideo` draws keywords from more than just the first frame,
    /// and that it produces results where an audio-only classification flow would produce
    /// none (this fixture never adds an audio track at all).
    @Test func analyzeVideoAggregatesAcrossSegments() async throws {
        let songbird = try VideoTestFixture.loadImage(at: TestBundleResources.shared.songbird)
        let sharksandwich = try VideoTestFixture.loadImage(at: TestBundleResources.shared.sharksandwich)

        let videoURL = try await VideoTestFixture.makeMultiSegmentTestVideo(
            segments: [songbird, sharksandwich],
            segmentDuration: 4.0
        )
        defer { try? FileManager.default.removeItem(at: videoURL) }

        let results = try await ImageClassification.analyzeVideo(
            url: videoURL,
            sampling: .fixedInterval(step: 2.0),
            minimumConfidence: 0.1
        ) ?? []

        let identifiers = results.map { $0.identifier }

        // From the songbird segment (verified real labels, see ImageClassificationTests).
        #expect(identifiers.contains("plant"))
        #expect(identifiers.contains("branch"))
        // From the sharksandwich segment (verified real labels: an illustrated album cover).
        #expect(identifiers.contains("art"))
        #expect(identifiers.contains("illustrations"))

        Log.debug(results)
    }

    @Test func stepLongerThanDurationSamplesOneFrame() async throws {
        let songbird = try VideoTestFixture.loadImage(at: TestBundleResources.shared.songbird)

        let videoURL = try await VideoTestFixture.makeMultiSegmentTestVideo(
            segments: [songbird],
            segmentDuration: 2.0
        )
        defer { try? FileManager.default.removeItem(at: videoURL) }

        // The step is far longer than the video's duration -- this must not crash or
        // silently produce zero sampled frames.
        let results = try await ImageClassification.analyzeVideo(
            url: videoURL,
            sampling: .fixedInterval(step: 100.0),
            minimumConfidence: 0.1
        ) ?? []

        #expect(!results.isEmpty)
        #expect(results.map { $0.identifier }.contains("plant"))
    }

    @Test func invalidSamplingStepThrows() async throws {
        let songbird = try VideoTestFixture.loadImage(at: TestBundleResources.shared.songbird)

        let videoURL = try await VideoTestFixture.makeMultiSegmentTestVideo(
            segments: [songbird],
            segmentDuration: 1.0
        )
        defer { try? FileManager.default.removeItem(at: videoURL) }

        await #expect(throws: ImageClassificationError.self) {
            _ = try await ImageClassification.analyzeVideo(
                url: videoURL,
                sampling: .fixedInterval(step: 0)
            )
        }
    }
}
