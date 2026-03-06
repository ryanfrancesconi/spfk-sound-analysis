# SPFKSoundAnalysis

ML sound classification for Swift, built on Apple's [SoundAnalysis](https://developer.apple.com/documentation/soundanalysis) framework.

## Features

- **Built-in Classification** — Classify audio files using Apple's `.version1` sound classifier with 300+ known sound categories (speech, music, laughter, etc.)
- **Custom ML Models** — Supply your own `MLModel` for domain-specific classification
- **Async/Await API** — Fully async interface with Swift concurrency and task cancellation support
- **Confidence Filtering** — Configurable minimum confidence threshold to filter low-quality results
- **Windowed Aggregation** — Automatically aggregates classifications across analysis windows, keeping the highest confidence per identifier
- **Overlap Control** — Adjustable overlap factor for analysis window granularity

## Architecture

```
┌──────────────────────────────────────────────────┐
│                SoundClassification               │
│  (Public API — async analyze, known categories)  │
├──────────────────────────────────────────────────┤
│         SNClassifySoundRequest                   │
│  (.version1 built-in  or  custom MLModel)        │
├──────────────────────────────────────────────────┤
│         SNAudioFileAnalyzer                      │
│  (Processes audio file in overlapping windows)   │
├──────────────────────────────────────────────────┤
│    SoundClassificationResultObserver             │
│  (Aggregates per-window results, filters by      │
│   confidence, sorts descending)                  │
└──────────────────────────────────────────────────┘
```

- **`SoundClassification`** — Entry point enum with static methods for analysis. Handles request creation, analyzer setup, and cancellation.
- **`SoundClassificationResultObserver`** — `SNResultsObserving` conformant observer that aggregates classification results across all analysis windows, retaining the highest confidence seen for each sound identifier.

## Usage

### Classify an Audio File (Built-in Classifier)

```swift
import SPFKSoundAnalysis

let url = URL(fileURLWithPath: "/path/to/audio.wav")
let results = try await SoundClassification.analyze(url: url)

for classification in results ?? [] {
    print("\(classification.identifier): \(classification.confidence)")
}
```

### Classify with Custom Confidence and Overlap

```swift
let results = try await SoundClassification.analyze(
    url: url,
    overlapFactor: 0.8,
    minimumConfidence: 0.5
)
```

### Classify with a Custom ML Model

```swift
let model = try MLModel(contentsOf: modelURL)
let results = try await SoundClassification.analyze(
    using: model,
    url: url
)
```

### Query Known Sound Categories

```swift
let categories = try SoundClassification.knownClassificationsForVersion1()
print("Available categories: \(categories.count)")
// speech, music, laughter, dog_bark, siren, ...
```

## Dependencies

| Package | Description |
|---------|-------------|
| [spfk-base](https://github.com/ryanfrancesconi/spfk-base) | Core utilities and extensions |
| [spfk-audio-base](https://github.com/ryanfrancesconi/spfk-audio-base) | Audio foundation types |
| [spfk-testing](https://github.com/ryanfrancesconi/spfk-testing) | Test infrastructure (test target only) |

## Requirements

- **Swift** 6.2+
- **macOS** 13+

## About

Spongefork (SPFK) is the personal software projects of [Ryan Francesconi](https://github.com/ryanfrancesconi). Dedicated to creative sound manipulation, his first application, Spongefork, was released in 1999 for macOS 8. From 2016 to 2025 he was the lead macOS developer at [Audio Design Desk](https://add.app).
