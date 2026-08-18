/// Copyright (c) 2026 Kodeco Inc. See COPYRIGHT for details.
/// Caution: This is AI-generated code.

import SwiftUI
import Charts

// MARK: - Detail screen · Ticket to Merge Days

struct TicketToMergeView: View {
  private let ticketToMergeViewModel = TicketToMergeViewModel()
  
  var body: some View {
    ScrollView {
      VStack(alignment: .leading, spacing: 24) {
        VStack(alignment: .leading, spacing: 4) {
          Text(ticketToMergeViewModel.periodLine)
            .font(.subheadline)
            .foregroundStyle(.secondary)
          Text(ticketToMergeViewModel.subtitleLine)
            .font(.subheadline)
            .foregroundStyle(.secondary)
        }
        lines
      }
      .padding(24)
    }
    .background(Color(.systemBackground))
    .navigationTitle("Ticket to Merge")
    .toolbarTitleDisplayMode(.inline)
  }
  
  private var lines: some View {
    Chart(ticketToMergeViewModel.points) { point in
      LineMark(
        x: .value(ticketToMergeViewModel.xAxisCaption, point.month, unit: .month),
        y: .value(ticketToMergeViewModel.yAxisCaption, point.avgDays)
      )
      .foregroundStyle(by: .value("Cohort", point.cohortName))
      .symbol(by: .value("Cohort", point.cohortName))
      .lineStyle(StrokeStyle(lineWidth: 2))
      .symbolSize(60)
    }
    .chartForegroundStyleScale(domain: ticketToMergeViewModel.cohortNames, range: [Color.indigo, Color.green])
    .chartYScale(domain: ticketToMergeViewModel.daysDomain)
    .chartYAxisLabel(ticketToMergeViewModel.yAxisCaption, position: .topTrailing)
    .chartYAxis {
      AxisMarks(position: .trailing)
    }
    .chartXAxis {
      AxisMarks(values: .stride(by: .month)) { _ in
        AxisGridLine()
        AxisValueLabel(format: .dateTime.month(.abbreviated))
      }
    }
    .chartLegend(position: .bottom, alignment: .leading)
    .frame(height: 320)
    .accessibilityLabel(accessibilitySummary)
  }
  
  private var accessibilitySummary: String {
    let pointSummaries = ticketToMergeViewModel.points
      .map(\.detailDisplay)
      .joined(separator: ", ")
    return "Line chart of average days from ticket to merge per month for heavy AI users versus light AI users. \(pointSummaries)"
  }
}

#Preview("Details · Ticket to Merge") {
  NavigationStack {
    TicketToMergeView()
  }
}
