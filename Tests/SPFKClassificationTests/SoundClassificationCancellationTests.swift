// Copyright Ryan Francesconi. All Rights Reserved.

import Foundation
import SPFKBase
import SPFKTesting
import Testing

@testable import SPFKClassification

@Suite(.tags(.file))
struct SoundClassificationCancellationTests {
    /// `SNAudioFileAnalyzer.analyze()` reports `false` for both a cancel and a failed read, so
    /// the enclosing task is what separates them. Without that check `PlaylistProcessor` records
    /// a cancel as a failed file and the run ends in an error dialog.
    @Test("a cancelled task throws CancellationError, not an analysis failure")
    func cancellationIsNotAnAnalysisFailure() async throws {
        let url = TestBundleResources.shared.tabla_wav

        // The result is discarded rather than returned — `SNClassification` is not `Sendable`.
        let task = Task {
            _ = try await SoundClassification.analyze(url: url)
        }
        task.cancel()

        await #expect(throws: CancellationError.self) {
            try await task.value
        }
    }
}
