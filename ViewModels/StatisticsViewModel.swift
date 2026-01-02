//
//  StatisticsViewModel.swift
//  QuillStack
//
//  Created on 2025-12-30.
//

import SwiftUI
import CoreData
import Combine

/// View model for capture statistics dashboard
@MainActor
class StatisticsViewModel: ObservableObject {
    // MARK: - Published Properties

    @Published private(set) var capturesByDay: [CaptureDay] = []
    @Published private(set) var typeDistribution: [TypeCount] = []
    @Published private(set) var accuracyTrend: [AccuracyPoint] = []
    @Published private(set) var learningStats: LearningStats = LearningStats()
    @Published private(set) var summaryStats: SummaryStats = SummaryStats()
    @Published private(set) var isLoading = false

    @Published var selectedTimeRange: TimeRange = .twoWeeks

    // MARK: - Private Properties

    private let context = CoreDataStack.shared.persistentContainer.viewContext
    private var cancellables = Set<AnyCancellable>()

    // MARK: - Initialization

    init() {
        loadStatistics()

        // Reload when time range changes
        $selectedTimeRange
            .dropFirst()
            .sink { [weak self] _ in
                self?.loadStatistics()
            }
            .store(in: &cancellables)
    }

    // MARK: - Public Methods

    func loadStatistics() {
        isLoading = true

        let startDate = selectedTimeRange.startDate

        // Load all statistics
        capturesByDay = fetchCapturesByDay(since: startDate)
        typeDistribution = fetchTypeDistribution()
        accuracyTrend = fetchAccuracyTrend(since: startDate)
        learningStats = fetchLearningStats()
        summaryStats = fetchSummaryStats()

        isLoading = false
    }

    // MARK: - Insights

    var mostProductiveDay: String? {
        let dayCounts = Dictionary(grouping: capturesByDay, by: { Calendar.current.component(.weekday, from: $0.date) })
        guard let maxDay = dayCounts.max(by: { $0.value.reduce(0) { $0 + $1.count } < $1.value.reduce(0) { $0 + $1.count } }) else {
            return nil
        }
        let formatter = DateFormatter()
        formatter.weekdaySymbols = formatter.weekdaySymbols
        return formatter.weekdaySymbols[maxDay.key - 1]
    }

    var averageNotesPerDay: Double {
        guard !capturesByDay.isEmpty else { return 0 }
        let total = capturesByDay.reduce(0) { $0 + $1.count }
        return Double(total) / Double(capturesByDay.count)
    }

    var accuracyImprovement: Double? {
        guard accuracyTrend.count >= 2 else { return nil }
        let firstWeekAvg = accuracyTrend.prefix(7).map { $0.confidence }.reduce(0, +) / Double(min(7, accuracyTrend.count))
        let lastWeekAvg = accuracyTrend.suffix(7).map { $0.confidence }.reduce(0, +) / Double(min(7, accuracyTrend.count))
        return lastWeekAvg - firstWeekAvg
    }

    // MARK: - Private Fetch Methods

    private func fetchCapturesByDay(since startDate: Date) -> [CaptureDay] {
        let request = NSFetchRequest<Note>(entityName: "Note")
        request.predicate = NSPredicate(format: "createdAt >= %@", startDate as NSDate)
        request.sortDescriptors = [NSSortDescriptor(key: "createdAt", ascending: true)]

        do {
            let notes = try context.fetch(request)
            let calendar = Calendar.current

            // Group by day
            let grouped = Dictionary(grouping: notes) { note -> Date in
                calendar.startOfDay(for: note.createdAt)
            }

            // Create CaptureDay entries for each day in range
            var result: [CaptureDay] = []
            var currentDate = calendar.startOfDay(for: startDate)
            let endDate = calendar.startOfDay(for: Date())

            while currentDate <= endDate {
                let count = grouped[currentDate]?.count ?? 0
                result.append(CaptureDay(date: currentDate, count: count))
                currentDate = calendar.date(byAdding: .day, value: 1, to: currentDate) ?? currentDate
            }

            return result
        } catch {
            print("Failed to fetch captures by day: \(error)")
            return []
        }
    }

    private func fetchTypeDistribution() -> [TypeCount] {
        let request = NSFetchRequest<Note>(entityName: "Note")
        request.predicate = NSPredicate(format: "isArchived == NO")

        do {
            let notes = try context.fetch(request)
            let grouped = Dictionary(grouping: notes) { $0.noteType }

            return grouped.map { type, notes in
                TypeCount(type: type, count: notes.count)
            }.sorted { $0.count > $1.count }
        } catch {
            print("Failed to fetch type distribution: \(error)")
            return []
        }
    }

    private func fetchAccuracyTrend(since startDate: Date) -> [AccuracyPoint] {
        let request = NSFetchRequest<Note>(entityName: "Note")
        request.predicate = NSPredicate(format: "createdAt >= %@ AND ocrConfidence > 0", startDate as NSDate)
        request.sortDescriptors = [NSSortDescriptor(key: "createdAt", ascending: true)]

        do {
            let notes = try context.fetch(request)
            let calendar = Calendar.current

            // Group by day and average confidence
            let grouped = Dictionary(grouping: notes) { note -> Date in
                calendar.startOfDay(for: note.createdAt)
            }

            return grouped.map { date, dayNotes in
                let avgConfidence = dayNotes.map { Double($0.ocrConfidence) }.reduce(0, +) / Double(dayNotes.count)
                return AccuracyPoint(date: date, confidence: avgConfidence)
            }.sorted { $0.date < $1.date }
        } catch {
            print("Failed to fetch accuracy trend: \(error)")
            return []
        }
    }

    private func fetchLearningStats() -> LearningStats {
        let request = NSFetchRequest<OCRCorrection>(entityName: "OCRCorrection")

        do {
            let corrections = try context.fetch(request)
            guard !corrections.isEmpty else {
                return LearningStats()
            }

            let mostFrequent = corrections.max(by: { $0.frequency < $1.frequency })

            return LearningStats(
                totalCorrections: corrections.count,
                mostFrequentOriginal: mostFrequent?.originalWord,
                mostFrequentCorrected: mostFrequent?.correctedWord,
                mostFrequentCount: mostFrequent.map { Int($0.frequency) } ?? 0
            )
        } catch {
            print("Failed to fetch learning stats: \(error)")
            return LearningStats()
        }
    }

    private func fetchSummaryStats() -> SummaryStats {
        let request = NSFetchRequest<Note>(entityName: "Note")

        do {
            let allNotes = try context.fetch(request)
            let activeNotes = allNotes.filter { !$0.isArchived }

            let calendar = Calendar.current
            let thisWeekStart = calendar.date(byAdding: .day, value: -7, to: Date()) ?? Date()
            let thisMonthStart = calendar.date(byAdding: .month, value: -1, to: Date()) ?? Date()

            let thisWeekNotes = activeNotes.filter { $0.createdAt >= thisWeekStart }
            let thisMonthNotes = activeNotes.filter { $0.createdAt >= thisMonthStart }

            let avgConfidence = activeNotes.isEmpty ? 0 : activeNotes.map { Double($0.ocrConfidence) }.reduce(0, +) / Double(activeNotes.count)

            return SummaryStats(
                totalNotes: activeNotes.count,
                notesThisWeek: thisWeekNotes.count,
                notesThisMonth: thisMonthNotes.count,
                averageConfidence: avgConfidence
            )
        } catch {
            print("Failed to fetch summary stats: \(error)")
            return SummaryStats()
        }
    }
}

// MARK: - Data Models

struct CaptureDay: Identifiable {
    let id = UUID()
    let date: Date
    let count: Int
}

struct TypeCount: Identifiable {
    let id = UUID()
    let type: String
    let count: Int

    var color: Color {
        switch type.lowercased() {
        case "todo": return .badgeTodo
        case "meeting": return .badgeMeeting
        case "email": return .badgeEmail
        case "claudeprompt": return .badgePrompt
        default: return .badgeGeneral
        }
    }

    var icon: String {
        switch type.lowercased() {
        case "todo": return "checkmark.square"
        case "meeting": return "calendar"
        case "email": return "envelope"
        case "claudeprompt": return "sparkles"
        default: return "doc.text"
        }
    }
}

struct AccuracyPoint: Identifiable {
    let id = UUID()
    let date: Date
    let confidence: Double
}

struct LearningStats {
    var totalCorrections: Int = 0
    var mostFrequentOriginal: String?
    var mostFrequentCorrected: String?
    var mostFrequentCount: Int = 0
}

struct SummaryStats {
    var totalNotes: Int = 0
    var notesThisWeek: Int = 0
    var notesThisMonth: Int = 0
    var averageConfidence: Double = 0
}

// MARK: - Time Range

enum TimeRange: String, CaseIterable, Identifiable {
    case oneWeek = "1W"
    case twoWeeks = "2W"
    case oneMonth = "1M"
    case threeMonths = "3M"
    case allTime = "All"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .oneWeek: return "1 Week"
        case .twoWeeks: return "2 Weeks"
        case .oneMonth: return "1 Month"
        case .threeMonths: return "3 Months"
        case .allTime: return "All Time"
        }
    }

    var startDate: Date {
        let calendar = Calendar.current
        switch self {
        case .oneWeek:
            return calendar.date(byAdding: .day, value: -7, to: Date()) ?? Date()
        case .twoWeeks:
            return calendar.date(byAdding: .day, value: -14, to: Date()) ?? Date()
        case .oneMonth:
            return calendar.date(byAdding: .month, value: -1, to: Date()) ?? Date()
        case .threeMonths:
            return calendar.date(byAdding: .month, value: -3, to: Date()) ?? Date()
        case .allTime:
            return calendar.date(byAdding: .year, value: -10, to: Date()) ?? Date()
        }
    }
}
