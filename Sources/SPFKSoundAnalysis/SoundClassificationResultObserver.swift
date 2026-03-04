import Foundation
import SoundAnalysis

/// Result for SoundAnalysis processing.
/// Aggregates classifications across all analysis windows,
/// keeping the highest confidence seen for each identifier.
public class SoundClassificationResultObserver: NSObject, SNResultsObserving {
    public private(set) var classifications: [SNClassification]?

    public let minimumConfidence: Double

    /// Tracks the best confidence seen per identifier across all windows
    private var bestByIdentifier: [String: SNClassification] = [:]

    public init(minimumConfidence: Double = SoundClassification.defaultConfidence) {
        self.minimumConfidence = minimumConfidence
    }

    public func request(_ request: SNRequest, didProduce result: SNResult) {
        guard let result = result as? SNClassificationResult else {
            return
        }

        for classification in result.classifications where classification.confidence >= minimumConfidence {
            let id = classification.identifier

            if let existing = bestByIdentifier[id] {
                if classification.confidence > existing.confidence {
                    bestByIdentifier[id] = classification
                }
            } else {
                bestByIdentifier[id] = classification
            }
        }

        classifications = bestByIdentifier.values
            .sorted { $0.confidence > $1.confidence }
    }
}
