//
//  ClassificationAnalyticsService.swift
//  QuillStack
//
//  Created on 2026-01-06.
//

import Foundation
import CoreData

/// Analytics service for tracking hashtag usage and classification methods.
/// Used to inform hashtag deprecation decisions (QUI-125).
@MainActor
class ClassificationAnalyticsService {

    static let shared = ClassificationAnalyticsService()

    private init() {}

    // MARK: - Data Models

    struct ClassificationStats {
        let totalNotes: Int
        let explicitCount: Int // Hashtag-based classification
        let llmCount: Int // AI-based classification
        let heuristicCount: Int // Pattern-based classification
        let unknownCount: Int // No classification method recorded

        var explicitPercentage: Double {
            guard totalNotes > 0 else { return 0.0 }
            return (Double(explicitCount) / Double(totalNotes)) * 100.0
        }

        var llmPercentage: Double {
            guard totalNotes > 0 else { return 0.0 }
            return (Double(llmCount) / Double(totalNotes)) * 100.0
        }

        var heuristicPercentage: Double {
            guard totalNotes > 0 else { return 0.0 }
            return (Double(heuristicCount) / Double(totalNotes)) * 100.0
        }
    }

    struct TrendDataPoint {
        let date: Date
        let explicitCount: Int
        let totalCount: Int

        var explicitPercentage: Double {
            guard totalCount > 0 else { return 0.0 }
            return (Double(explicitCount) / Double(totalCount)) * 100.0
        }
    }

    struct TypeBreakdown {
        let noteType: String
        let explicitCount: Int
        let totalCount: Int

        var explicitPercentage: Double {
            guard totalCount > 0 else { return 0.0 }
            return (Double(explicitCount) / Double(totalCount)) * 100.0
        }
    }

    // MARK: - Overall Statistics

    /// Get overall classification statistics for all notes
    func getOverallStats(context: NSManagedObjectContext) -> ClassificationStats? {
        let fetchRequest = NSFetchRequest<Note>(entityName: "Note")

        do {
            let notes = try context.fetch(fetchRequest)

            let explicitCount = notes.filter { $0.classificationMethod == "explicit" }.count
            let llmCount = notes.filter { $0.classificationMethod == "llm" }.count
            let heuristicCount = notes.filter { $0.classificationMethod == "heuristic" }.count
            let unknownCount = notes.filter { $0.classificationMethod == nil }.count

            return ClassificationStats(
                totalNotes: notes.count,
                explicitCount: explicitCount,
                llmCount: llmCount,
                heuristicCount: heuristicCount,
                unknownCount: unknownCount
            )
        } catch {
            print("Error fetching classification stats: \(error)")
            return nil
        }
    }

    // MARK: - Time-based Trend Analysis

    /// Get trend data for the last N days
    func getTrendData(days: Int, context: NSManagedObjectContext) -> [TrendDataPoint] {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())

        var trendData: [TrendDataPoint] = []

        for dayOffset in (0..<days).reversed() {
            guard let date = calendar.date(byAdding: .day, value: -dayOffset, to: today) else {
                continue
            }

            guard let nextDate = calendar.date(byAdding: .day, value: 1, to: date) else {
                continue
            }

            let fetchRequest = NSFetchRequest<Note>(entityName: "Note")
            fetchRequest.predicate = NSPredicate(
                format: "createdAt >= %@ AND createdAt < %@",
                date as NSDate,
                nextDate as NSDate
            )

            do {
                let notes = try context.fetch(fetchRequest)
                let explicitCount = notes.filter { $0.classificationMethod == "explicit" }.count

                trendData.append(TrendDataPoint(
                    date: date,
                    explicitCount: explicitCount,
                    totalCount: notes.count
                ))
            } catch {
                print("Error fetching trend data for \(date): \(error)")
            }
        }

        return trendData
    }

    // MARK: - Type-based Breakdown

    /// Get hashtag usage breakdown by note type
    func getTypeBreakdown(context: NSManagedObjectContext) -> [TypeBreakdown] {
        let fetchRequest = NSFetchRequest<Note>(entityName: "Note")

        do {
            let notes = try context.fetch(fetchRequest)

            // Group by note type
            let notesByType = Dictionary(grouping: notes) { $0.noteType }

            return notesByType.map { noteType, notesOfType in
                let explicitCount = notesOfType.filter { $0.classificationMethod == "explicit" }.count
                return TypeBreakdown(
                    noteType: noteType,
                    explicitCount: explicitCount,
                    totalCount: notesOfType.count
                )
            }
            .sorted { $0.totalCount > $1.totalCount } // Sort by total count descending
        } catch {
            print("Error fetching type breakdown: \(error)")
            return []
        }
    }

    // MARK: - Recent Usage Analysis

    /// Get statistics for notes created in the last N days
    func getRecentStats(days: Int, context: NSManagedObjectContext) -> ClassificationStats? {
        let calendar = Calendar.current
        guard let startDate = calendar.date(byAdding: .day, value: -days, to: Date()) else {
            return nil
        }

        let fetchRequest = NSFetchRequest<Note>(entityName: "Note")
        fetchRequest.predicate = NSPredicate(format: "createdAt >= %@", startDate as NSDate)

        do {
            let notes = try context.fetch(fetchRequest)

            let explicitCount = notes.filter { $0.classificationMethod == "explicit" }.count
            let llmCount = notes.filter { $0.classificationMethod == "llm" }.count
            let heuristicCount = notes.filter { $0.classificationMethod == "heuristic" }.count
            let unknownCount = notes.filter { $0.classificationMethod == nil }.count

            return ClassificationStats(
                totalNotes: notes.count,
                explicitCount: explicitCount,
                llmCount: llmCount,
                heuristicCount: heuristicCount,
                unknownCount: unknownCount
            )
        } catch {
            print("Error fetching recent stats: \(error)")
            return nil
        }
    }

    // MARK: - Decision Support

    /// Generate a recommendation for hashtag deprecation based on usage data
    func getDeprecationRecommendation(context: NSManagedObjectContext) -> String {
        guard let recentStats = getRecentStats(days: 90, context: context) else {
            return "Insufficient data to make a recommendation."
        }

        let explicitPercentage = recentStats.explicitPercentage

        if explicitPercentage < 5.0 {
            return "Hashtag usage is very low (<5%). Consider removing UI hints and moving towards deprecation."
        } else if explicitPercentage > 20.0 {
            return "Hashtag usage is significant (>20%). Keep as a documented power-user feature."
        } else {
            return "Hashtag usage is moderate (5-20%). Continue monitoring trends before making deprecation decisions."
        }
    }
}
