/// Copyright (c) 2026 Kodeco Inc. See COPYRIGHT for details.
/// Caution: This is AI-generated code.

import SwiftUI
import Charts

// MARK: - Detail screen · cost by model

struct CostbyModelView: View {
  private let costByModelViewModel = CostByModelViewModel()

  var body: some View {
    ScrollView {
      VStack(alignment: .leading, spacing: 24) {
        Text(costByModelViewModel.periodLine)
          .font(.subheadline)
          .foregroundStyle(.secondary)
        donut
        rankedList
      }
      .padding(24)
    }
    .background(Color(.systemBackground))
    .navigationTitle("Cost by Model")
    .toolbarTitleDisplayMode(.inline)
  }

  private var donut: some View {
    Chart(costByModelViewModel.slices) { slice in
      SectorMark(
        angle: .value("Cost", slice.cost),
        innerRadius: .ratio(0.66),
        angularInset: 1.5
      )
      .cornerRadius(3)
      .foregroundStyle(by: .value("Model", slice.name))
    }
    .chartForegroundStyleScale(domain: costByModelViewModel.sliceNames, range: ColorStyles.shades)
    .chartLegend(.hidden)
    .frame(height: 240)
    .overlay {
      VStack(spacing: 2) {
        Text(costByModelViewModel.totalDisplay)
          .font(.system(.title, design: .serif, weight: .semibold))
        Text("total spend")
          .font(.caption)
          .foregroundStyle(.secondary)
      }
    }
    .accessibilityLabel("Donut chart of month to date cost by model, total \(costByModelViewModel.totalDisplay)")
  }

  private var rankedList: some View {
    VStack(spacing: 0) {
      ForEach(Array(costByModelViewModel.slices.enumerated()), id: \.element.id) { index, slice in
        SliceRow(slice: slice, swatch: ColorStyles.shades[index % ColorStyles.shades.count])
        Divider()
      }
    }
  }
}

private struct SliceRow: View {
  let slice: CostByModelViewModel.Slice
  let swatch: Color

  var body: some View {
    HStack(spacing: 12) {
      Circle()
        .fill(swatch)
        .frame(width: 10, height: 10)
      VStack(alignment: .leading, spacing: 2) {
        Text(slice.name)
          .font(.body.weight(.medium))
        Text("\(slice.shareDisplay) of spend · \(slice.changeDisplay) MoM")
          .font(.caption)
          .foregroundStyle(.secondary)
      }
      Spacer()
      Text(slice.costDisplay)
        .font(.system(.body, design: .serif, weight: .semibold))
    }
    .padding(.vertical, 14)
    .accessibilityElement(children: .combine)
  }
}

#Preview("Details · Cost by Model") {
  NavigationStack {
    CostbyModelView()
  }
}
