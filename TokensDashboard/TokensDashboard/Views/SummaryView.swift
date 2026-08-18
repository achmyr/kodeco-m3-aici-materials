/// Copyright (c) 2026 Kodeco Inc. See COPYRIGHT for details.
/// Caution: This is AI-generated code.

import SwiftUI

// MARK: - Summary view model (narrative brief)

/// The detail graph screen an insight on the summary drills into.
enum DestinationGraph: Hashable {
  case costByModel
  case tokensVsOutcomes
  case ticketToMerge
}

private struct Heading: View {
  let title: String
  let subtitle: String
  
  var body: some View {
    VStack(alignment: .leading, spacing: 6) {
      Text(title)
        .font(.system(.largeTitle, design: .serif, weight: .semibold))
      Text(subtitle)
        .font(.subheadline)
        .foregroundStyle(.secondary)
    }
    .padding(.vertical, 24)
    .frame(maxWidth: .infinity, alignment: .leading)
  }
}

// MARK: - Summary screen (narrative brief)

struct SummaryView: View {
  private let summaryViewModel = SummaryViewModel()
  
  var body: some View {
    ScrollView {
      VStack(alignment: .leading, spacing: 0) {
        Heading(title: "Token's Dashboard Summary", subtitle: summaryViewModel.dateLine)
        ForEach(summaryViewModel.insights) { insight in
          NavigationLink(value: insight.destination) {
            InsightRow(insight: insight)
          }
          .buttonStyle(.plain)
          Divider()
        }
      }
      .padding(.horizontal, 24)
    }
    .background(Color(.systemBackground))
    .navigationTitle("")
    .toolbarTitleDisplayMode(.inline)
    .navigationDestination(for: DestinationGraph.self) { destination in
      switch destination {
      case .costByModel: CostbyModelView()
      case .tokensVsOutcomes: TokensOutcomesView()
      case .ticketToMerge: TicketToMergeView()
      }
    }
  }
}

// Caution: This is AI-generated code.

private struct InsightRow: View {
  let insight: SummaryViewModel.Insight
  
  var body: some View {
    VStack(alignment: .leading, spacing: 8) {
      HStack(alignment: .firstTextBaseline, spacing: 8) {
        Text(insight.headline)
          .font(.system(.title2, design: .serif, weight: .semibold))
        Spacer(minLength: 0)
        Image(systemName: "chevron.right")
          .font(.footnote.weight(.semibold))
          .foregroundStyle(.tertiary)
      }
      Text(insight.detail)
        .font(.subheadline)
        .foregroundStyle(.secondary)
    }
    .padding(.vertical, 18)
    .frame(maxWidth: .infinity, alignment: .leading)
    .contentShape(Rectangle())
    .accessibilityElement(children: .combine)
    .accessibilityLabel("\(insight.headline) \(insight.detail)")
  }
}

// MARK: - Previews

#Preview("Summary") {
  NavigationStack {
    SummaryView()
  }
}


