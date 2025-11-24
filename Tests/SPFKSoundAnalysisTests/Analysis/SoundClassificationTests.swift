import Foundation
import SPFKAudioBase
import SPFKBase
@testable import SPFKSoundAnalysis
import SPFKTesting
import Testing

@Suite(.serialized, .tags(.file))
final class SoundClassificationTests: TestCaseModel {
    @Test func analyze() async throws {
        let url = TestBundleResources.shared.tabla_wav

        let results = try await SoundClassification.analyze(url: url)

        let identifiers = results?.compactMap { $0.identifier }

        #expect(
            identifiers == ["music", "tabla", "drum", "percussion"]
        )

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

        #expect(identifiers == ["music", "percussion", "bell", "drum", "cowbell"])
    }
}
