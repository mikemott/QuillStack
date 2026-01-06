//
//  UsageMetricsView.swift
//  QuillStack
//
//  Created on 2026-01-06.
//

import SwiftUI

struct UsageMetricsView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @Environment(\.dismiss) private var dismiss

    @State private var overallStats: ClassificationAnalyticsService.ClassificationStats?
    @State private var recentStats: ClassificationAnalyticsService.ClassificationStats?
    @State private var trendData: [ClassificationAnalyticsService.TrendDataPoint] = []
    @State private var typeBreakdown: [ClassificationAnalyticsService.TypeBreakdown] = []
    @State private var recommendation: String = ""

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    // Header
                    headerSection

                    // Overall Statistics
                    if let stats = overallStats {
                        overallStatsCard(stats)
                    }

                    // Recent Trends (Last 30 days)
                    if let recent = recentStats {
                        recentStatsCard(recent)
                    }

                    // Deprecation Recommendation
                    if !recommendation.isEmpty {
                        recommendationCard
                    }

                    // Type Breakdown
                    if !typeBreakdown.isEmpty {
                        typeBreakdownSection
                    }

                    // Trend Chart (Last 30 days)
                    if !trendData.isEmpty {
                        trendChartSection
                    }
                }
                .padding()
            }
            .background(Color.creamLight)
            .navigationTitle("Classification Metrics")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                    .foregroundColor(.forestDark)
                }
            }
            .onAppear {
                loadData()
            }
        }
    }

    // MARK: - Sections

    private var headerSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Hashtag Usage Tracking")
                .font(.serifTitle(24, weight: .bold))
                .foregroundColor(.forestDark)

            Text("Monitor classification method usage to inform future deprecation decisions.")
                .font(.serifBody(14, weight: .regular))
                .foregroundColor(.textMedium)
                .lineSpacing(4)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func overallStatsCard(_ stats: ClassificationAnalyticsService.ClassificationStats) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "chart.bar.fill")
                    .foregroundColor(.forestDark)
                Text("All Time Statistics")
                    .font(.serifBody(16, weight: .semibold))
                    .foregroundColor(.forestDark)
            }

            Divider()

            VStack(spacing: 8) {
                statRow(label: "Total Notes", value: "\(stats.totalNotes)")
                statRow(label: "Hashtag Usage", value: "\(stats.explicitCount) (\(String(format: "%.1f%%", stats.explicitPercentage)))")
                statRow(label: "AI Classification", value: "\(stats.llmCount) (\(String(format: "%.1f%%", stats.llmPercentage)))")
                statRow(label: "Pattern-Based", value: "\(stats.heuristicCount) (\(String(format: "%.1f%%", stats.heuristicPercentage)))")
            }
        }
        .padding(16)
        .background(Color.paperBeige)
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.05), radius: 4, x: 0, y: 2)
    }

    private func recentStatsCard(_ stats: ClassificationAnalyticsService.ClassificationStats) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "calendar")
                    .foregroundColor(.forestDark)
                Text("Last 30 Days")
                    .font(.serifBody(16, weight: .semibold))
                    .foregroundColor(.forestDark)
            }

            Divider()

            VStack(spacing: 8) {
                statRow(label: "Total Notes", value: "\(stats.totalNotes)")
                statRow(label: "Hashtag Usage", value: "\(stats.explicitCount) (\(String(format: "%.1f%%", stats.explicitPercentage)))")
                statRow(label: "AI Classification", value: "\(stats.llmCount) (\(String(format: "%.1f%%", stats.llmPercentage)))")
            }
        }
        .padding(16)
        .background(Color.paperBeige)
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.05), radius: 4, x: 0, y: 2)
    }

    private var recommendationCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "lightbulb.fill")
                    .foregroundColor(.forestDark)
                Text("Recommendation")
                    .font(.serifBody(16, weight: .semibold))
                    .foregroundColor(.forestDark)
            }

            Divider()

            Text(recommendation)
                .font(.serifBody(14, weight: .regular))
                .foregroundColor(.textDark)
                .lineSpacing(4)
        }
        .padding(16)
        .background(
            LinearGradient(
                colors: [Color.forestLight.opacity(0.2), Color.forestLight.opacity(0.1)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.05), radius: 4, x: 0, y: 2)
    }

    private var typeBreakdownSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "list.bullet")
                    .foregroundColor(.forestDark)
                Text("Usage by Note Type")
                    .font(.serifBody(16, weight: .semibold))
                    .foregroundColor(.forestDark)
            }

            Divider()

            ForEach(typeBreakdown.prefix(10), id: \.noteType) { breakdown in
                HStack {
                    Text(breakdown.noteType.capitalized)
                        .font(.serifBody(14, weight: .regular))
                        .foregroundColor(.textDark)

                    Spacer()

                    Text("\(breakdown.explicitCount)/\(breakdown.totalCount)")
                        .font(.system(size: 12, weight: .medium, design: .monospaced))
                        .foregroundColor(.textMedium)

                    Text("(\(String(format: "%.0f%%", breakdown.explicitPercentage)))")
                        .font(.system(size: 12, weight: .medium, design: .monospaced))
                        .foregroundColor(.textMedium)
                        .frame(width: 50, alignment: .trailing)
                }
                .padding(.vertical, 4)
            }
        }
        .padding(16)
        .background(Color.paperBeige)
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.05), radius: 4, x: 0, y: 2)
    }

    private var trendChartSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "chart.line.uptrend.xyaxis")
                    .foregroundColor(.forestDark)
                Text("30-Day Trend")
                    .font(.serifBody(16, weight: .semibold))
                    .foregroundColor(.forestDark)
            }

            Divider()

            // Simple text-based trend display
            VStack(alignment: .leading, spacing: 4) {
                ForEach(trendData.suffix(7), id: \.date) { dataPoint in
                    HStack {
                        Text(dataPoint.date, style: .date)
                            .font(.system(size: 12, weight: .regular, design: .monospaced))
                            .foregroundColor(.textMedium)
                            .frame(width: 100, alignment: .leading)

                        Text("\(dataPoint.explicitCount)/\(dataPoint.totalCount)")
                            .font(.system(size: 12, weight: .medium, design: .monospaced))
                            .foregroundColor(.textDark)
                            .frame(width: 60, alignment: .trailing)

                        // Simple bar visualization
                        if dataPoint.totalCount > 0 {
                            GeometryReader { geometry in
                                HStack(spacing: 0) {
                                    Rectangle()
                                        .fill(Color.forestMedium)
                                        .frame(width: geometry.size.width * CGFloat(dataPoint.explicitPercentage / 100.0))

                                    Spacer(minLength: 0)
                                }
                            }
                            .frame(height: 12)
                            .background(Color.gray.opacity(0.2))
                            .cornerRadius(4)

                            Text("\(String(format: "%.0f%%", dataPoint.explicitPercentage))")
                                .font(.system(size: 12, weight: .medium, design: .monospaced))
                                .foregroundColor(.textMedium)
                                .frame(width: 40, alignment: .trailing)
                        }
                    }
                }
            }
        }
        .padding(16)
        .background(Color.paperBeige)
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.05), radius: 4, x: 0, y: 2)
    }

    // MARK: - Helper Views

    private func statRow(label: String, value: String) -> some View {
        HStack {
            Text(label)
                .font(.serifBody(14, weight: .regular))
                .foregroundColor(.textMedium)

            Spacer()

            Text(value)
                .font(.system(size: 14, weight: .semibold, design: .monospaced))
                .foregroundColor(.forestDark)
        }
    }

    // MARK: - Data Loading

    private func loadData() {
        let service = ClassificationAnalyticsService.shared

        // Load overall stats
        overallStats = service.getOverallStats(context: viewContext)

        // Load recent stats (last 30 days)
        recentStats = service.getRecentStats(days: 30, context: viewContext)

        // Load trend data (last 30 days)
        trendData = service.getTrendData(days: 30, context: viewContext)

        // Load type breakdown
        typeBreakdown = service.getTypeBreakdown(context: viewContext)

        // Get recommendation
        recommendation = service.getDeprecationRecommendation(context: viewContext)
    }
}

#Preview {
    UsageMetricsView()
        .environment(\.managedObjectContext, CoreDataStack.preview.context)
}
