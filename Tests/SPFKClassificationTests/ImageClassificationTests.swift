import Foundation
import SPFKBase
@testable import SPFKClassification
import SPFKTesting
import Testing
import Vision

@Suite(.tags(.file))
final class ImageClassificationTests: TestCaseModel {
    @Test func analyze() async throws {
        let url = TestBundleResources.shared.songbird

        let results = try await ImageClassification.analyze(url: url)
        let identifiers = results?.map(\.identifier) ?? []

        // Verified against real Vision output: this photo's highest-confidence
        // classifications are all well above the default 0.6 threshold. Vision's
        // classifier weighs this photo's dominant blurred foliage over the bird itself
        // (confirmed across both Revision1 and Revision2): "bird" scores only ~0.05-0.32,
        // well below a usable threshold, so it's deliberately not asserted here.
        #expect(identifiers.contains("plant"))
        #expect(identifiers.contains("branch"))
        #expect(identifiers.contains("foliage"))

        Log.debug(results)
    }

    @Test func highConfidenceFiltersResults() async throws {
        let url = TestBundleResources.shared.songbird

        let lowConfResults = try await ImageClassification.analyze(
            url: url,
            minimumConfidence: 0.1
        ) ?? []

        let highConfResults = try await ImageClassification.analyze(
            url: url,
            minimumConfidence: 0.9
        ) ?? []

        // "branch" and "foliage" score below 0.9 for this fixture (confirmed against real
        // output), so a 0.9 threshold must exclude them while a 0.1 threshold keeps them.
        let lowIdentifiers = lowConfResults.map(\.identifier)
        let highIdentifiers = highConfResults.map(\.identifier)

        #expect(lowIdentifiers.contains("branch"))
        #expect(lowIdentifiers.contains("foliage"))
        #expect(!highIdentifiers.contains("branch"))
        #expect(!highIdentifiers.contains("foliage"))

        #expect(highConfResults.count < lowConfResults.count)

        for result in highConfResults {
            #expect(result.confidence >= 0.9)
        }
    }

    @Test func invalidURLThrows() async throws {
        let url = URL(fileURLWithPath: "/nonexistent/path/to/image.jpg")

        await #expect(throws: (any Error).self) {
            _ = try await ImageClassification.analyze(url: url)
        }
    }

    @Test func cancellationThrows() async throws {
        let url = TestBundleResources.shared.songbird

        // VNClassificationObservation isn't Sendable, so the task discards its result
        // internally (returning Void) rather than letting it cross the task boundary.
        let task = Task<Void, Error> {
            _ = try await ImageClassification.analyze(url: url)
        }
        task.cancel()

        await #expect(throws: (any Error).self) {
            try await task.value
        }
    }

    @Test func knownClassifications() throws {
        let list = try ImageClassification.knownClassifications()

        #expect(!list.isEmpty)
        // Built-in classifier has over 1000 known identifiers
        #expect(list.count > 1000)
        // Spot check a few known identifiers
        #expect(list.contains("plant"))
        #expect(list.contains("bird"))
        #expect(list.contains("branch"))
    }
}
