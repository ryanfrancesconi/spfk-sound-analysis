import Foundation
import SPFKAudioBase
import SPFKBase
@testable import SPFKSoundAnalysis
import SoundAnalysis
import SPFKTesting
import Testing

@Suite(.serialized, .tags(.file))
final class SoundClassificationTests: TestCaseModel {
    @Test func analyze() async throws {
        let url = TestBundleResources.shared.tabla_wav

        let results = try await SoundClassification.analyze(url: url)

        let identifiers = results?.compactMap { $0.identifier } ?? []

        // Tabla should be classified as music with percussion-related identifiers
        #expect(identifiers.contains("music"))
        #expect(identifiers.contains("tabla"))
        #expect(identifiers.contains("drum"))

        Log.debug(results)
    }

    // if a file is too short then there isn't enough chance for the analysis to succeed, so loop it a few time
    // and process that file
    @Test func duplicateInsufficientDataAndAnalyze() async throws {
        let url = TestBundleResources.shared.cowbell_wav

        let tmp = try await AudioTools.createLoopedAudio(input: url, minimumDuration: 20)

        let results = try await SoundClassification.analyze(url: tmp, overlapFactor: 0.5, minimumConfidence: 0.1) ?? []
        let identifiers = results.map { $0.identifier }

        Log.debug(url.path, "=", results)

        #expect(identifiers.contains("music"))
        #expect(identifiers.contains("cowbell"))
        #expect(identifiers.contains("bell"))
    }

    @Test func knownClassificationsForVersion1() throws {
        let list = try SoundClassification.knownClassificationsForVersion1()

        #expect(!list.isEmpty)
        // Version 1 classifier has over 300 known classifications
        #expect(list.count > 300)
        // Spot check a few known identifiers
        #expect(list.contains("speech"))
        #expect(list.contains("music"))
        #expect(list.contains("laughter"))
    }

    @Test func highConfidenceFiltersResults() async throws {
        let url = TestBundleResources.shared.tabla_wav

        // With very high confidence threshold, fewer results should pass
        let highConfResults = try await SoundClassification.analyze(
            url: url,
            minimumConfidence: 0.9
        ) ?? []

        let defaultResults = try await SoundClassification.analyze(
            url: url,
            minimumConfidence: 0.1
        ) ?? []

        // Higher confidence threshold should produce fewer or equal results
        #expect(highConfResults.count <= defaultResults.count)

        // All returned results should meet the confidence threshold
        for result in highConfResults {
            #expect(result.confidence >= 0.9)
        }
    }

    @Test func invalidURLThrows() async throws {
        let url = URL(fileURLWithPath: "/nonexistent/path/to/audio.wav")

        await #expect(throws: (any Error).self) {
            _ = try await SoundClassification.analyze(url: url)
        }
    }

    @Test func resultsSortedByConfidence() async throws {
        let url = TestBundleResources.shared.tabla_wav

        let results = try await SoundClassification.analyze(
            url: url,
            minimumConfidence: 0.1
        ) ?? []

        // Verify results are sorted by descending confidence
        for i in 0 ..< results.count - 1 {
            #expect(results[i].confidence >= results[i + 1].confidence)
        }
    }

    @Test func observerDefaults() {
        let observer = SoundClassificationResultObserver()
        #expect(observer.minimumConfidence == SoundClassification.defaultConfidence)
        #expect(observer.classifications == nil)
    }

    @Test func observerCustomConfidence() {
        let observer = SoundClassificationResultObserver(minimumConfidence: 0.8)
        #expect(observer.minimumConfidence == 0.8)
        #expect(observer.classifications == nil)
    }
}
