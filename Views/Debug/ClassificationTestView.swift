//
//  ClassificationTestView.swift
//  QuillStack
//
//  Debug view for running classification accuracy tests
//

import SwiftUI

@MainActor
struct ClassificationTestView: View {
    @State private var isRunning = false
    @State private var results: ClassificationTestResults?
    @State private var logText: String = ""

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // Header
                VStack(alignment: .leading, spacing: 8) {
                    Text("Classification Accuracy Test")
                        .font(.title2)
                        .fontWeight(.bold)

                    Text("Tests LLM classification against \(ClassificationTestSuite.allTests.count) examples")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                .padding()

                // Run button
                Button(action: runTests) {
                    HStack {
                        if isRunning {
                            ProgressView()
                                .padding(.trailing, 8)
                        }
                        Text(isRunning ? "Running Tests..." : "Run All Tests")
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                }
                .buttonStyle(.borderedProminent)
                .disabled(isRunning)
                .padding(.horizontal)

                // Results summary
                if let results = results {
                    VStack(alignment: .leading, spacing: 16) {
                        // Overall accuracy
                        GroupBox {
                            HStack {
                                VStack(alignment: .leading) {
                                    Text("Overall Accuracy")
                                        .font(.headline)
                                    Text("\(results.correct) / \(results.totalTests) correct")
                                        .font(.subheadline)
                                        .foregroundColor(.secondary)
                                }
                                Spacer()
                                Text("\(String(format: "%.1f%%", results.accuracy * 100))")
                                    .font(.system(.title, design: .rounded))
                                    .fontWeight(.bold)
                                    .foregroundColor(accuracyColor(results.accuracy))
                            }
                        }
                        .padding(.horizontal)

                        // By type
                        GroupBox("Accuracy by Note Type") {
                            VStack(alignment: .leading, spacing: 8) {
                                ForEach(Array(results.resultsByType.sorted(by: { $0.value.total > $1.value.total })), id: \.key) { type, typeResults in
                                    HStack {
                                        statusIcon(typeResults.accuracy)
                                        Text(type.rawValue.capitalized)
                                            .font(.subheadline)
                                        Spacer()
                                        Text("\(typeResults.correct)/\(typeResults.total)")
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                        Text("\(String(format: "%.0f%%", typeResults.accuracy * 100))")
                                            .font(.subheadline)
                                            .fontWeight(.semibold)
                                            .foregroundColor(accuracyColor(typeResults.accuracy))
                                            .frame(width: 50, alignment: .trailing)
                                    }
                                }
                            }
                        }
                        .padding(.horizontal)

                        // By difficulty
                        GroupBox("Accuracy by Difficulty") {
                            VStack(alignment: .leading, spacing: 8) {
                                ForEach([ClassificationTestCase.Difficulty.easy, .medium, .hard], id: \.self) { difficulty in
                                    if let diffResults = results.resultsByDifficulty[difficulty] {
                                        HStack {
                                            statusIcon(diffResults.accuracy)
                                            Text("\(difficulty)".capitalized)
                                                .font(.subheadline)
                                            Spacer()
                                            Text("\(diffResults.correct)/\(diffResults.total)")
                                                .font(.caption)
                                                .foregroundColor(.secondary)
                                            Text("\(String(format: "%.0f%%", diffResults.accuracy * 100))")
                                                .font(.subheadline)
                                                .fontWeight(.semibold)
                                                .foregroundColor(accuracyColor(diffResults.accuracy))
                                                .frame(width: 50, alignment: .trailing)
                                        }
                                    }
                                }
                            }
                        }
                        .padding(.horizontal)

                        // Failures
                        if !results.failures.isEmpty {
                            GroupBox("Failures (\(results.failures.count))") {
                                VStack(alignment: .leading, spacing: 12) {
                                    ForEach(Array(results.failures.prefix(10).enumerated()), id: \.offset) { index, failure in
                                        VStack(alignment: .leading, spacing: 4) {
                                            HStack {
                                                Text("\(failure.testCase.id)")
                                                    .font(.caption)
                                                    .fontWeight(.semibold)
                                                Spacer()
                                                Text("\(failure.testCase.difficulty)")
                                                    .font(.caption)
                                                    .padding(.horizontal, 6)
                                                    .padding(.vertical, 2)
                                                    .background(Color.secondary.opacity(0.2))
                                                    .cornerRadius(4)
                                            }

                                            HStack {
                                                Text("Expected:")
                                                    .font(.caption)
                                                    .foregroundColor(.secondary)
                                                Text(failure.testCase.expectedType.rawValue)
                                                    .font(.caption)
                                                    .fontWeight(.medium)
                                            }

                                            HStack {
                                                Text("Got:")
                                                    .font(.caption)
                                                    .foregroundColor(.secondary)
                                                Text(failure.actualType.rawValue)
                                                    .font(.caption)
                                                    .fontWeight(.medium)
                                                Text("(\(String(format: "%.0f%%", failure.actualConfidence * 100)))")
                                                    .font(.caption)
                                                    .foregroundColor(.secondary)
                                            }

                                            if let notes = failure.testCase.notes {
                                                Text(notes)
                                                    .font(.caption)
                                                    .foregroundColor(.secondary)
                                                    .italic()
                                            }
                                        }
                                        .padding(.vertical, 4)

                                        if index < min(9, results.failures.count - 1) {
                                            Divider()
                                        }
                                    }

                                    if results.failures.count > 10 {
                                        Text("... and \(results.failures.count - 10) more")
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                            .padding(.top, 4)
                                    }
                                }
                            }
                            .padding(.horizontal)
                        }

                        // Recommendations
                        GroupBox("Recommendations") {
                            VStack(alignment: .leading, spacing: 8) {
                                if results.accuracy >= 0.85 {
                                    RecommendationRow(
                                        icon: "checkmark.circle.fill",
                                        color: .green,
                                        text: "LLM classification performing well (≥ 85%)"
                                    )
                                    RecommendationRow(
                                        icon: "arrow.right.circle",
                                        color: .blue,
                                        text: "Ready to proceed with spatial segmentation"
                                    )
                                    RecommendationRow(
                                        icon: "number.circle",
                                        color: .blue,
                                        text: "Hashtags can be optional/override only"
                                    )
                                } else if results.accuracy >= 0.70 {
                                    RecommendationRow(
                                        icon: "exclamationmark.triangle.fill",
                                        color: .orange,
                                        text: "Improve prompts before spatial segmentation"
                                    )
                                    RecommendationRow(
                                        icon: "number.circle",
                                        color: .orange,
                                        text: "Keep hashtags as primary for low-accuracy types"
                                    )
                                } else {
                                    RecommendationRow(
                                        icon: "xmark.circle.fill",
                                        color: .red,
                                        text: "LLM needs significant improvement"
                                    )
                                    RecommendationRow(
                                        icon: "wrench.fill",
                                        color: .red,
                                        text: "Focus on prompt engineering"
                                    )
                                }
                            }
                        }
                        .padding(.horizontal)
                    }
                }

                // Console output
                if !logText.isEmpty {
                    GroupBox("Console Output") {
                        ScrollView {
                            Text(logText)
                                .font(.system(.caption, design: .monospaced))
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                        .frame(height: 200)
                    }
                    .padding(.horizontal)
                }

                Spacer(minLength: 40)
            }
        }
        .navigationTitle("Classification Test")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func runTests() {
        isRunning = true
        logText = "Starting tests...\n"
        results = nil

        Task {
            let tester = ClassificationAccuracyTester()
            let testResults = await tester.runAllTests()

            await MainActor.run {
                results = testResults
                isRunning = false

                // Generate log output
                var log = ""
                log += "Completed \(testResults.totalTests) tests\n"
                log += "Accuracy: \(String(format: "%.1f%%", testResults.accuracy * 100))\n\n"

                if !testResults.failures.isEmpty {
                    log += "Failures:\n"
                    for failure in testResults.failures.prefix(5) {
                        log += "  - \(failure.testCase.id): expected \(failure.testCase.expectedType.rawValue), got \(failure.actualType.rawValue)\n"
                    }
                    if testResults.failures.count > 5 {
                        log += "  ... and \(testResults.failures.count - 5) more\n"
                    }
                }

                logText = log

                // Also print to console for debugging
                testResults.printReport()
            }
        }
    }

    private func accuracyColor(_ accuracy: Double) -> Color {
        if accuracy >= 0.9 {
            return .green
        } else if accuracy >= 0.7 {
            return .orange
        } else {
            return .red
        }
    }

    private func statusIcon(_ accuracy: Double) -> some View {
        Group {
            if accuracy >= 0.9 {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundColor(.green)
            } else if accuracy >= 0.7 {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundColor(.orange)
            } else {
                Image(systemName: "xmark.circle.fill")
                    .foregroundColor(.red)
            }
        }
    }
}

struct RecommendationRow: View {
    let icon: String
    let color: Color
    let text: String

    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: icon)
                .foregroundColor(color)
                .frame(width: 20)
            Text(text)
                .font(.subheadline)
        }
    }
}

#Preview {
    NavigationStack {
        ClassificationTestView()
    }
}
