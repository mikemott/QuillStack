//
//  ClassificationAccuracyTest.swift
//  QuillStack
//
//  Test runner for measuring LLM classification accuracy
//

import Foundation
import UIKit

/// Results from running classification accuracy tests
struct ClassificationTestResults {
    let totalTests: Int
    let correct: Int
    let incorrect: Int
    let accuracy: Double
    let resultsByType: [NoteType: TypeResults]
    let resultsByDifficulty: [ClassificationTestCase.Difficulty: DifficultyResults]
    let failures: [TestFailure]

    struct TypeResults {
        let total: Int
        let correct: Int
        let incorrect: Int
        var accuracy: Double {
            total > 0 ? Double(correct) / Double(total) : 0.0
        }
    }

    struct DifficultyResults {
        let total: Int
        let correct: Int
        let incorrect: Int
        var accuracy: Double {
            total > 0 ? Double(correct) / Double(total) : 0.0
        }
    }

    struct TestFailure {
        let testCase: ClassificationTestCase
        let actualType: NoteType
        let actualConfidence: Double
        let method: ClassificationMethod
        let reasoning: String?
    }

    /// Print formatted results to console
    func printReport() {
        print("\n" + String(repeating: "=", count: 60))
        print("CLASSIFICATION ACCURACY TEST RESULTS")
        print(String(repeating: "=", count: 60))
        print("\nOVERALL:")
        print("  Total Tests: \(totalTests)")
        print("  Correct: \(correct)")
        print("  Incorrect: \(incorrect)")
        print("  Accuracy: \(String(format: "%.1f%%", accuracy * 100))")

        print("\n" + String(repeating: "-", count: 60))
        print("ACCURACY BY NOTE TYPE:")
        print(String(repeating: "-", count: 60))

        let sortedTypes = resultsByType.sorted { $0.value.total > $1.value.total }
        for (type, results) in sortedTypes {
            let status = results.accuracy >= 0.9 ? "✅" : results.accuracy >= 0.7 ? "⚠️" : "❌"
            print(String(format: "  %@ %-15s: %2d/%2d (%.1f%%)",
                         status,
                         type.rawValue.capitalized,
                         results.correct,
                         results.total,
                         results.accuracy * 100))
        }

        print("\n" + String(repeating: "-", count: 60))
        print("ACCURACY BY DIFFICULTY:")
        print(String(repeating: "-", count: 60))

        let difficulties: [ClassificationTestCase.Difficulty] = [.easy, .medium, .hard]
        for difficulty in difficulties {
            if let results = resultsByDifficulty[difficulty] {
                let status = results.accuracy >= 0.9 ? "✅" : results.accuracy >= 0.7 ? "⚠️" : "❌"
                print(String(format: "  %@ %-10s: %2d/%2d (%.1f%%)",
                             status,
                             "\(difficulty)".capitalized,
                             results.correct,
                             results.total,
                             results.accuracy * 100))
            }
        }

        if !failures.isEmpty {
            print("\n" + String(repeating: "-", count: 60))
            print("FAILURES (\(failures.count)):")
            print(String(repeating: "-", count: 60))

            for (index, failure) in failures.enumerated() {
                print("\n\(index + 1). \(failure.testCase.id) - Difficulty: \(failure.testCase.difficulty)")
                print("   Expected: \(failure.testCase.expectedType.rawValue)")
                print("   Got: \(failure.actualType.rawValue) (confidence: \(String(format: "%.0f%%", failure.actualConfidence * 100)))")
                print("   Method: \(failure.method.displayName)")
                if let reasoning = failure.reasoning {
                    print("   Reasoning: \(reasoning)")
                }
                if let notes = failure.testCase.notes {
                    print("   Notes: \(notes)")
                }
                print("   Text preview: \(failure.testCase.text.prefix(100))...")
            }
        }

        print("\n" + String(repeating: "=", count: 60))
        print("RECOMMENDATIONS:")
        print(String(repeating: "=", count: 60))

        // Analyze results and provide recommendations
        let lowAccuracyTypes = resultsByType.filter { $0.value.accuracy < 0.7 }
        if !lowAccuracyTypes.isEmpty {
            print("\n⚠️  Low accuracy types (< 70%):")
            for (type, results) in lowAccuracyTypes {
                print("   - \(type.rawValue): \(String(format: "%.1f%%", results.accuracy * 100))")
            }
            print("\n   Recommendation: These types may need:")
            print("   1. Improved LLM prompts with examples")
            print("   2. Keep hashtags as primary method")
            print("   3. Additional heuristic rules")
        }

        let mediumAccuracyTypes = resultsByType.filter { $0.value.accuracy >= 0.7 && $0.value.accuracy < 0.9 }
        if !mediumAccuracyTypes.isEmpty {
            print("\n⚠️  Medium accuracy types (70-90%):")
            for (type, results) in mediumAccuracyTypes {
                print("   - \(type.rawValue): \(String(format: "%.1f%%", results.accuracy * 100))")
            }
            print("\n   Recommendation: Improve with:")
            print("   1. Better prompt engineering")
            print("   2. Few-shot examples in prompt")
            print("   3. Confidence threshold tuning")
        }

        let highAccuracyTypes = resultsByType.filter { $0.value.accuracy >= 0.9 }
        if !highAccuracyTypes.isEmpty {
            print("\n✅ High accuracy types (>= 90%):")
            for (type, results) in highAccuracyTypes {
                print("   - \(type.rawValue): \(String(format: "%.1f%%", results.accuracy * 100))")
            }
            print("\n   Recommendation: These can use auto-detection reliably")
        }

        if accuracy >= 0.85 {
            print("\n✅ OVERALL: LLM classification is performing well (>= 85%)")
            print("   → Proceed with spatial segmentation")
            print("   → Hashtags can be optional/override")
        } else if accuracy >= 0.70 {
            print("\n⚠️  OVERALL: LLM classification needs improvement (70-85%)")
            print("   → Improve prompts before spatial segmentation")
            print("   → Keep hashtags as primary for low-accuracy types")
        } else {
            print("\n❌ OVERALL: LLM classification needs significant work (< 70%)")
            print("   → Focus on prompt engineering first")
            print("   → Consider keeping hashtags as primary method")
            print("   → May need more heuristic rules")
        }

        print("\n" + String(repeating: "=", count: 60) + "\n")
    }

    /// Export results as JSON
    func exportJSON() -> String {
        // Simple JSON export for further analysis
        var json = "{\n"
        json += "  \"overall\": {\n"
        json += "    \"total\": \(totalTests),\n"
        json += "    \"correct\": \(correct),\n"
        json += "    \"incorrect\": \(incorrect),\n"
        json += "    \"accuracy\": \(accuracy)\n"
        json += "  },\n"
        json += "  \"by_type\": [\n"

        let typeEntries = resultsByType.map { type, results in
            """
                {
                  "type": "\(type.rawValue)",
                  "total": \(results.total),
                  "correct": \(results.correct),
                  "accuracy": \(results.accuracy)
                }
            """
        }
        json += typeEntries.joined(separator: ",\n")
        json += "\n  ]\n"
        json += "}"
        return json
    }
}

/// Test runner for classification accuracy
@MainActor
class ClassificationAccuracyTester {
    private let classifier: TextClassifierProtocol

    init(classifier: TextClassifierProtocol) {
        self.classifier = classifier
    }

    convenience init() {
        self.init(classifier: TextClassifier())
    }

    /// Run all tests and return results
    func runAllTests() async -> ClassificationTestResults {
        print("Running \(ClassificationTestSuite.allTests.count) classification tests...")
        print("This may take a few minutes due to LLM API calls...\n")

        var correct = 0
        var incorrect = 0
        var failures: [ClassificationTestResults.TestFailure] = []
        var typeStats: [NoteType: (total: Int, correct: Int, incorrect: Int)] = [:]
        var difficultyStats: [ClassificationTestCase.Difficulty: (total: Int, correct: Int, incorrect: Int)] = [:]

        for (index, testCase) in ClassificationTestSuite.allTests.enumerated() {
            print("[\(index + 1)/\(ClassificationTestSuite.allTests.count)] Testing \(testCase.id)...", terminator: " ")

            // Run classification
            let result = await classifier.classifyNoteAsync(content: testCase.text, image: nil)

            // Check if correct
            let isCorrect = result.type == testCase.expectedType

            if isCorrect {
                correct += 1
                print("✅")
            } else {
                incorrect += 1
                print("❌ Expected: \(testCase.expectedType.rawValue), Got: \(result.type.rawValue)")

                failures.append(ClassificationTestResults.TestFailure(
                    testCase: testCase,
                    actualType: result.type,
                    actualConfidence: result.confidence,
                    method: result.method,
                    reasoning: result.reasoning
                ))
            }

            // Update type stats
            var typeStat = typeStats[testCase.expectedType] ?? (0, 0, 0)
            typeStat.total += 1
            if isCorrect {
                typeStat.correct += 1
            } else {
                typeStat.incorrect += 1
            }
            typeStats[testCase.expectedType] = typeStat

            // Update difficulty stats
            var difficultyStat = difficultyStats[testCase.difficulty] ?? (0, 0, 0)
            difficultyStat.total += 1
            if isCorrect {
                difficultyStat.correct += 1
            } else {
                difficultyStat.incorrect += 1
            }
            difficultyStats[testCase.difficulty] = difficultyStat

            // Small delay to avoid rate limiting
            try? await Task.sleep(nanoseconds: 100_000_000) // 0.1 second
        }

        // Build results
        let resultsByType = typeStats.mapValues {
            ClassificationTestResults.TypeResults(total: $0.total, correct: $0.correct, incorrect: $0.incorrect)
        }

        let resultsByDifficulty = difficultyStats.mapValues {
            ClassificationTestResults.DifficultyResults(total: $0.total, correct: $0.correct, incorrect: $0.incorrect)
        }

        let accuracy = Double(correct) / Double(ClassificationTestSuite.allTests.count)

        return ClassificationTestResults(
            totalTests: ClassificationTestSuite.allTests.count,
            correct: correct,
            incorrect: incorrect,
            accuracy: accuracy,
            resultsByType: resultsByType,
            resultsByDifficulty: resultsByDifficulty,
            failures: failures
        )
    }

    /// Run tests for a specific category
    func runTests(for category: ClassificationTestCase.TestCategory) async -> ClassificationTestResults {
        let tests = ClassificationTestSuite.tests(for: category)
        print("Running \(tests.count) \(category) tests...\n")

        // Similar implementation to runAllTests but with filtered tests
        // (Implementation omitted for brevity - would be similar to runAllTests)
        fatalError("Not implemented - use runAllTests for now")
    }
}

/// Convenience function to run tests from anywhere
@MainActor
func runClassificationAccuracyTests() async {
    let tester = ClassificationAccuracyTester()
    let results = await tester.runAllTests()
    results.printReport()
}
