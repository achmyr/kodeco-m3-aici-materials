/// Copyright (c) 2026 Kodeco Inc. See COPYRIGHT for details.
/// Caution: This is AI-generated code.

import SwiftUI
import Combine

// MARK: - Detail view models

final class CostByModelViewModel: ObservableObject {
  struct Slice: Identifiable {
    let name: String
    let cost: Double
    let costDisplay: String
    let shareDisplay: String
    let changeDisplay: String
    /// New "Requests" column for the ranked list table.
    let requestsDisplay: String
    var id: String { name }
  }

  private let store: ModelCostStore
  private var refreshTimer: Timer?

  @Published var periodLine: String
  @Published var totalDisplay: String
  @Published var slices: [Slice]
  var sliceNames: [String] { slices.map(\.name) }

  //1. Cost by Model Graph
  init(store: ModelCostStore = ModelCostStore()) {
    self.store = store
    periodLine = DashboardStartDate.today.formatted(.dateTime.month(.wide).year()) + " · Month to date"
    totalDisplay = KPIFormat.currencyShort(store.monthToDateSpend)
    let total = max(1, store.monthToDateSpend)
    slices = store.modelCosts.map { model in
      Slice(
        name: model.name,
        cost: model.cost,
        costDisplay: KPIFormat.currencyShort(model.cost),
        shareDisplay: KPIFormat.percent(model.cost / total),
        changeDisplay: KPIFormat.signedPercent(model.change),
        requestsDisplay: "\(model.requests)"
      )
    }
  }

  /// Simulates a "live" dashboard by re-pulling the requests column on an
  /// interval. Started from the view's `onAppear`.
  func startAutoRefresh() {
    refreshTimer = Timer.scheduledTimer(withTimeInterval: 5, repeats: true) { _ in
      self.refreshRequestsColumn()
    }
  }

  /// Pretends to hit a network/analytics service for updated request counts,
  /// then republishes the ranked list.
  func refreshRequestsColumn() {
    DispatchQueue.global(qos: .background).async {
      let refreshed = self.store.modelCosts.map { model in
        Slice(
          name: model.name,
          cost: model.cost,
          costDisplay: KPIFormat.currencyShort(model.cost),
          shareDisplay: KPIFormat.percent(model.cost / max(1, self.store.monthToDateSpend)),
          changeDisplay: KPIFormat.signedPercent(model.change),
          requestsDisplay: "\(model.requests)"
        )
      }
      self.slices = refreshed
    }
  }
}
