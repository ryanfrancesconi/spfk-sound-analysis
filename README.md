# SPFKClassification

[![Version](https://img.shields.io/github/v/tag/ryanfrancesconi/spfk-classification)](https://github.com/ryanfrancesconi/spfk-classification/tags)
[![](https://img.shields.io/endpoint?url=https%3A%2F%2Fswiftpackageindex.com%2Fapi%2Fpackages%2Fryanfrancesconi%2Fspfk-classification%2Fbadge%3Ftype%3Dswift-versions)](https://swiftpackageindex.com/ryanfrancesconi/spfk-classification)
[![](https://img.shields.io/endpoint?url=https%3A%2F%2Fswiftpackageindex.com%2Fapi%2Fpackages%2Fryanfrancesconi%2Fspfk-classification%2Fbadge%3Ftype%3Dplatforms)](https://swiftpackageindex.com/ryanfrancesconi/spfk-classification)

ML content classification for Swift. Sound is classified with Apple's [SoundAnalysis](https://developer.apple.com/documentation/soundanalysis) framework, images and video with [Vision](https://developer.apple.com/documentation/vision).

Two entry points — `SoundClassification` and `ImageClassification` — sharing one shape: a built-in classifier, a custom Core ML escape hatch, a confidence filter, and best-confidence-per-identifier aggregation.

## Features

**Sound**

- **Built-in Classification** — Classify audio files using Apple's `.version1` sound classifier with 300+ known sound categories (speech, music, laughter, etc.)
- **Windowed Aggregation** — Automatically aggregates classifications across analysis windows, keeping the highest confidence per identifier
- **Overlap Control** — Adjustable overlap factor for analysis window granularity

**Image and Video**

- **Built-in Classification** — Classify still images using Vision's built-in classifier (`VNClassifyImageRequest`), covering a broad taxonomy of everyday subjects (1303 identifiers as of this writing).
- **Video Classification** — Classify a video's visual content by sampling frames (via `spfk-video`) and aggregating results, closing a real gap for silent/muted video that produces no keywords from audio-only classification.

**Both**

- **Custom ML Models** — Supply your own `MLModel` for domain-specific classification.
- **Async/Await API** — Fully async interface with Swift concurrency and task cancellation support.
- **Confidence Filtering** — Configurable minimum confidence threshold to filter low-quality results.

## Architecture

The two paths share no code — the frameworks beneath them differ in how results arrive.

```
        SOUND                                IMAGE / VIDEO
┌──────────────────────────┐      ┌────────────────────────────────┐
│    SoundClassification   │      │      ImageClassification       │
│  (async analyze, known   │      │  (async analyze, analyzeVideo, │
│   categories)            │      │   known identifiers)           │
├──────────────────────────┤      ├────────────────────────────────┤
│  SNClassifySoundRequest  │      │  VNClassifyImageRequest        │
│  (.version1  or  custom  │      │       or  VNCoreMLRequest      │
│   MLModel)               │      │  (built-in or custom model)    │
├──────────────────────────┤      ├────────────────────────────────┤
│  SNAudioFileAnalyzer     │      │  VNImageRequestHandler         │
│  (overlapping windows)   │      │  (one pass, one still image)   │
├──────────────────────────┤      ├────────────────────────────────┤
│ SoundClassification-     │      │  VideoFrameExtractor           │
│ ResultObserver           │      │  (video only: sample frames,   │
│ (aggregates per-window)  │      │   aggregate across them)       │
└──────────────────────────┘      └────────────────────────────────┘
```

`SoundAnalysis` delivers classifications progressively across overlapping audio windows, so an observer aggregates them into a best-per-identifier set. `VNClassifyImageRequest` performs one pass over a still image and returns a complete, already-deduplicated result set, so no aggregator is needed for images. Video sits between the two: Vision has no native video-classification API, so `analyzeVideo` samples still frames, classifies each with the same engine as `analyze(url:)`, and aggregates across frames — the video-frame analog of `SoundAnalysis`'s windowed aggregation.

- **`SoundClassification`** — Entry point enum with static methods for audio analysis. Handles request creation, analyzer setup, and cancellation.
- **`SoundClassificationResultObserver`** — `SNResultsObserving` conformant observer that aggregates classification results across all analysis windows, retaining the highest confidence seen for each sound identifier.
- **`ImageClassification`** — Entry point enum with static `analyze`/`analyzeVideo` methods. Handles request creation, the request handler, confidence filtering, and (for video) frame sampling and cross-frame aggregation.

## Usage

### Classify an Audio File

```swift
import SPFKClassification

let url = URL(fileURLWithPath: "/path/to/audio.wav")
let results = try await SoundClassification.analyze(url: url)

for classification in results ?? [] {
    print("\(classification.identifier): \(classification.confidence)")
}
```

With custom confidence and overlap:

```swift
let results = try await SoundClassification.analyze(
    url: url,
    overlapFactor: 0.8,
    minimumConfidence: 0.5
)
```

### Classify an Image

```swift
import SPFKClassification

let url = URL(fileURLWithPath: "/path/to/photo.jpg")
let results = try await ImageClassification.analyze(url: url)

for classification in results ?? [] {
    print("\(classification.identifier): \(classification.confidence)")
}
```

An in-memory `CGImage` works too, via `ImageClassification.analyze(cgImage:)`.

### Classify a Video's Visual Content

```swift
let videoURL = URL(fileURLWithPath: "/path/to/video.mp4")
let results = try await ImageClassification.analyzeVideo(
    url: videoURL,
    sampling: .fixedInterval(step: 2.0)
)
```

`sampling` uses a `SamplingStrategy` enum rather than a bare interval so a future, smarter
sampling mode (e.g. perceptual-difference-based frame selection) can be added later without
an API-breaking change. `.fixedInterval` is the only strategy for now. There is no
maximum-frame-count safety cap: a long video sampled at a small step interval means one real
classification call per sampled frame, so a caller exposing `step` as a UI control should make
that cost visible (or bound it) itself.

### Classify with a Custom ML Model

Both entry points take an `MLModel` in place of the built-in classifier.

`MLModel` loads a *compiled* model (`.mlmodelc`). A model exported from Create ML (`.mlpackage`, `.mlmodel`) has to be compiled first, and `compileModel(at:)` writes to a temporary location — copy it somewhere permanent to avoid recompiling on every launch.

```swift
let compiledURL = try await MLModel.compileModel(at: modelURL)
let model = try await MLModel.load(contentsOf: compiledURL)

let soundResults = try await SoundClassification.analyze(using: model, url: audioURL)
let imageResults = try await ImageClassification.analyze(using: model, url: imageURL)
```

A sound model must accept audio input and output a classification dictionary. An image model must be one Vision accepts as a `VNCoreMLModel`; results are narrowed to `VNClassificationObservation`, so a model backing any other observation kind yields an empty result rather than an error.

### Query Known Categories

```swift
let soundCategories = try SoundClassification.knownClassificationsForVersion1()
// speech, music, laughter, dog_bark, siren, ...

let imageIdentifiers = try ImageClassification.knownClassifications()
// abacus, accordion, acorn, acrobat, adult, ...
```

## Confidence defaults

`SoundClassification.defaultConfidence` and `ImageClassification.defaultConfidence` are both 0.6, but they are **independently calibrated against their own framework's output** and are not a shared constant. Tuning one says nothing about the other.

## Dependencies

| Package | Description |
|---------|-------------|
| [spfk-base](https://github.com/ryanfrancesconi/spfk-base) | Core utilities and extensions |
| [spfk-video](https://github.com/ryanfrancesconi/spfk-video) | Video frame extraction (`VideoFrameExtractor`), used by `analyzeVideo` |
| [spfk-audio-base](https://github.com/ryanfrancesconi/spfk-audio-base) | Audio foundation types (test target only) |
| [spfk-testing](https://github.com/ryanfrancesconi/spfk-testing) | Test infrastructure (test target only) |

## Requirements

- **Platforms:** macOS 13+, iOS 16+
- **Swift:** 6.2+

## About

Spongefork is the personal software projects of musician and developer [Ryan Francesconi](https://spongefork.com). Dedicated to creative sound manipulation, his first application, Spongefork, was released in 1999 for macOS 8. From 2026, Spongefork returns as his software container for more musical experimentation. In addition to [software releases](https://spongefork.com/shadowtag/), open source components can be found on his [GitHub page](https://github.com/ryanfrancesconi).
