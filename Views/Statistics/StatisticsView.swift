//
//  StatisticsView.swift
//  QuillStack
//
//  Created on 2025-12-30.
//

import SwiftUI
import Charts

struct StatisticsView: View {
    @StateObject private var viewModel = StatisticsViewModel()

    var body: some View {
        NavigationStack {
            ZStack {
                Color.creamLight.ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 20) {
                        // Time range picker
                        timeRangePicker

                        // Summary cards
                        summarySection

                        // Capture activity chart
                        captureActivitySection

                        // Type distribution
                        typeDistributionSection

                        // OCR accuracy trend
                        accuracyTrendSection

                        // Learning progress
                        learningProgressSection

                        // Insights
                        insightsSection
                    }
                    .padding(.horizontal, 20)
                    .padding(.bottom, 20)
                }
            }
            .navigationTitle("Statistics")
            .navigationBarTitleDisplayMode(.large)
            .refreshable {
                viewModel.loadStatistics()
            }
        }
    }

    // MARK: - Time Range Picker

    private var timeRangePicker: some View {
        HStack(spacing: 8) {
            ForEach(TimeRange.allCases) { range in
                Button(action: {
                    withAnimation {
                        viewModel.selectedTimeRange = range
                    }
                }) {
                    Text(range.rawValue)
                        .font(.serifCaption(13, weight: viewModel.selectedTimeRange == range ? .bold : .medium))
                        .foregroundColor(viewModel.selectedTimeRange == range ? .white : .textDark)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(
                            viewModel.selectedTimeRange == range
                                ? Color.forestDark
                                : Color.white
                        )
                        .cornerRadius(8)
                }
            }
        }
        .padding(.top, 8)
    }

    // MARK: - Summary Section

    private var summarySection: some View {
        HStack(spacing: 12) {
            SummaryCard(
                title: "Total Notes",
                value: "\(viewModel.summaryStats.totalNotes)",
                icon: "doc.text.fill",
                color: .forestDark
            )

            SummaryCard(
                title: "This Week",
                value: "\(viewModel.summaryStats.notesThisWeek)",
                icon: "calendar",
                color: .badgeMeeting
            )

            SummaryCard(
                title: "Avg. OCR",
                value: "\(Int(viewModel.summaryStats.averageConfidence * 100))%",
                icon: "text.viewfinder",
                color: .badgeTodo
            )
        }
    }

    // MARK: - Capture Activity

    private var captureActivitySection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("CAPTURE ACTIVITY")
                .font(.serifCaption(11, weight: .bold))
                .foregroundColor(.textMedium)
                .tracking(1)

            ChartCard {
                if viewModel.capturesByDay.isEmpty {
                    emptyChartPlaceholder(message: "No captures yet")
                } else {
                    Chart(viewModel.capturesByDay) { day in
                        BarMark(
                            x: .value("Date", day.date, unit: .day),
                            y: .value("Notes", day.count)
                        )
                        .foregroundStyle(
                            LinearGradient(
                                colors: [Color.forestDark, Color.forestMedium],
                                startPoint: .bottom,
                                endPoint: .top
                            )
                        )
                        .cornerRadius(4)
                    }
                    .chartXAxis {
                        AxisMarks(values: .stride(by: .day, count: axisStride)) { value in
                            AxisValueLabel(format: .dateTime.weekday(.narrow))
                        }
                    }
                    .chartYAxis {
                        AxisMarks { value in
                            AxisValueLabel()
                            AxisGridLine()
                        }
                    }
                    .frame(height: 150)
                }
            }

            // Summary text
            let totalInRange = viewModel.capturesByDay.reduce(0) { $0 + $1.count }
            Text("\(totalInRange) notes in selected period")
                .font(.serifCaption(12, weight: .regular))
                .foregroundColor(.textMedium)
        }
    }

    private var axisStride: Int {
        switch viewModel.selectedTimeRange {
        case .oneWeek: return 1
        case .twoWeeks: return 2
        case .oneMonth: return 5
        case .threeMonths: return 10
        case .allTime: return 30
        }
    }

    // MARK: - Type Distribution

    private var typeDistributionSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("NOTE TYPES")
                .font(.serifCaption(11, weight: .bold))
                .foregroundColor(.textMedium)
                .tracking(1)

            ChartCard {
                if viewModel.typeDistribution.isEmpty {
                    emptyChartPlaceholder(message: "No notes yet")
                } else {
                    HStack(spacing: 20) {
                        // Pie chart
                        Chart(viewModel.typeDistribution) { type in
                            SectorMark(
                                angle: .value("Count", type.count),
                                innerRadius: .ratio(0.5),
                                angularInset: 2
                            )
                            .foregroundStyle(type.color)
                            .cornerRadius(4)
                        }
                        .frame(width: 120, height: 120)

                        // Legend
                        VStack(alignment: .leading, spacing: 8) {
                            ForEach(viewModel.typeDistribution) { type in
                                HStack(spacing: 8) {
                                    Image(systemName: type.icon)
                                        .font(.system(size: 12))
                                        .foregroundColor(type.color)
                                        .frame(width: 16)

                                    Text(type.type.capitalized)
                                        .font(.serifBody(13, weight: .medium))
                                        .foregroundColor(.textDark)

                                    Spacer()

                                    Text("\(type.count)")
                                        .font(.serifBody(13, weight: .bold))
                                        .foregroundColor(.textDark)
                                }
                            }
                        }
                    }
                    .padding(.vertical, 8)
                }
            }
        }
    }

    // MARK: - Accuracy Trend

    private var accuracyTrendSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("OCR ACCURACY TREND")
                .font(.serifCaption(11, weight: .bold))
                .foregroundColor(.textMedium)
                .tracking(1)

            ChartCard {
                if viewModel.accuracyTrend.isEmpty {
                    emptyChartPlaceholder(message: "Not enough data")
                } else {
                    Chart(viewModel.accuracyTrend) { point in
                        LineMark(
                            x: .value("Date", point.date),
                            y: .value("Confidence", point.confidence * 100)
                        )
                        .foregroundStyle(Color.forestDark)
                        .lineStyle(StrokeStyle(lineWidth: 2))

                        AreaMark(
                            x: .value("Date", point.date),
                            y: .value("Confidence", point.confidence * 100)
                        )
                        .foregroundStyle(
                            LinearGradient(
                                colors: [Color.forestDark.opacity(0.3), Color.forestDark.opacity(0.05)],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                    }
                    .chartYScale(domain: 0...100)
                    .chartYAxis {
                        AxisMarks(values: [0, 25, 50, 75, 100]) { value in
                            AxisValueLabel {
                                if let intValue = value.as(Int.self) {
                                    Text("\(intValue)%")
                                }
                            }
                            AxisGridLine()
                        }
                    }
                    .frame(height: 120)
                }
            }

            // Improvement indicator
            if let improvement = viewModel.accuracyImprovement {
                HStack(spacing: 4) {
                    Image(systemName: improvement >= 0 ? "arrow.up.right" : "arrow.down.right")
                        .foregroundColor(improvement >= 0 ? .green : .orange)
                    Text(improvement >= 0 ? "+\(Int(improvement * 100))%" : "\(Int(improvement * 100))%")
                        .font(.serifCaption(12, weight: .semibold))
                        .foregroundColor(improvement >= 0 ? .green : .orange)
                    Text("change over period")
                        .font(.serifCaption(12, weight: .regular))
                        .foregroundColor(.textMedium)
                }
            }
        }
    }

    // MARK: - Learning Progress

    private var learningProgressSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("LEARNING PROGRESS")
                .font(.serifCaption(11, weight: .bold))
                .foregroundColor(.textMedium)
                .tracking(1)

            ChartCard {
                VStack(alignment: .leading, spacing: 16) {
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("\(viewModel.learningStats.totalCorrections)")
                                .font(.serifHeadline(28, weight: .bold))
                                .foregroundColor(.forestDark)
                            Text("corrections learned")
                                .font(.serifCaption(12, weight: .regular))
                                .foregroundColor(.textMedium)
                        }

                        Spacer()

                        Image(systemName: "brain.head.profile")
                            .font(.system(size: 32))
                            .foregroundColor(.forestLight)
                    }

                    if let original = viewModel.learningStats.mostFrequentOriginal,
                       let corrected = viewModel.learningStats.mostFrequentCorrected {
                        Divider()

                        VStack(alignment: .leading, spacing: 4) {
                            Text("Most frequent fix:")
                                .font(.serifCaption(11, weight: .medium))
                                .foregroundColor(.textMedium)

                            HStack(spacing: 8) {
                                Text("\"\(original)\"")
                                    .font(.serifBody(14, weight: .regular))
                                    .foregroundColor(.textLight)
                                    .strikethrough()

                                Image(systemName: "arrow.right")
                                    .font(.system(size: 12))
                                    .foregroundColor(.forestDark)

                                Text("\"\(corrected)\"")
                                    .font(.serifBody(14, weight: .medium))
                                    .foregroundColor(.forestDark)

                                Text("(\(viewModel.learningStats.mostFrequentCount)x)")
                                    .font(.serifCaption(11, weight: .regular))
                                    .foregroundColor(.textMedium)
                            }
                        }
                    }
                }
            }
        }
    }

    // MARK: - Insights

    private var insightsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("INSIGHTS")
                .font(.serifCaption(11, weight: .bold))
                .foregroundColor(.textMedium)
                .tracking(1)

            VStack(spacing: 12) {
                if let productiveDay = viewModel.mostProductiveDay {
                    InsightCard(
                        icon: "star.fill",
                        text: "Your most productive day is \(productiveDay)",
                        color: .badgeMeeting
                    )
                }

                if viewModel.averageNotesPerDay > 0 {
                    InsightCard(
                        icon: "chart.line.uptrend.xyaxis",
                        text: "You capture about \(String(format: "%.1f", viewModel.averageNotesPerDay)) notes per day",
                        color: .forestDark
                    )
                }

                if let improvement = viewModel.accuracyImprovement, improvement > 0.05 {
                    InsightCard(
                        icon: "sparkles",
                        text: "Great progress! Your OCR accuracy has improved by \(Int(improvement * 100))%",
                        color: .green
                    )
                }

                if viewModel.summaryStats.notesThisWeek > viewModel.summaryStats.notesThisMonth / 4 {
                    InsightCard(
                        icon: "flame.fill",
                        text: "You're on fire! More notes this week than your monthly average",
                        color: .badgeEmail
                    )
                }
            }
        }
    }

    // MARK: - Helpers

    private func emptyChartPlaceholder(message: String) -> some View {
        VStack(spacing: 8) {
            Image(systemName: "chart.bar.xaxis")
                .font(.system(size: 32))
                .foregroundColor(.textLight)
            Text(message)
                .font(.serifCaption(12, weight: .medium))
                .foregroundColor(.textMedium)
        }
        .frame(height: 120)
        .frame(maxWidth: .infinity)
    }
}

// MARK: - Supporting Views

struct SummaryCard: View {
    let title: String
    let value: String
    let icon: String
    let color: Color

    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 20))
                .foregroundColor(color)

            Text(value)
                .font(.serifHeadline(20, weight: .bold))
                .foregroundColor(.textDark)

            Text(title)
                .font(.serifCaption(10, weight: .medium))
                .foregroundColor(.textMedium)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 16)
        .background(Color.white)
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.05), radius: 4, x: 0, y: 2)
    }
}

struct ChartCard<Content: View>: View {
    @ViewBuilder let content: Content

    var body: some View {
        content
            .padding(16)
            .background(Color.white)
            .cornerRadius(12)
            .shadow(color: .black.opacity(0.05), radius: 4, x: 0, y: 2)
    }
}

struct InsightCard: View {
    let icon: String
    let text: String
    let color: Color

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 16))
                .foregroundColor(color)
                .frame(width: 32, height: 32)
                .background(color.opacity(0.15))
                .cornerRadius(8)

            Text(text)
                .font(.serifBody(14, weight: .regular))
                .foregroundColor(.textDark)
                .lineLimit(2)

            Spacer()
        }
        .padding(12)
        .background(Color.white)
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.05), radius: 4, x: 0, y: 2)
    }
}

#Preview {
    StatisticsView()
}
