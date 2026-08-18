/// Copyright (c) 2026 Kodeco Inc. See COPYRIGHT for details.
/// Caution: This is AI-generated code.

import SwiftUI

// MARK: - Detail view models

struct CostByModelViewModel {
  struct Slice: Identifiable {
    let name: String
    let cost: Double
    let costDisplay: String
    let shareDisplay: String
    let changeDisplay: String
    var id: String { name }
  }
  
  let periodLine: String
  let totalDisplay: String
  let slices: [Slice]
  var sliceNames: [String] { slices.map(\.name) }
  
  //1. Cost by Model Graph
  init(store: ModelCostStore = ModelCostStore()) {
    periodLine = DashboardStartDate.today.formatted(.dateTime.month(.wide).year()) + " · Month to date"
    totalDisplay = KPIFormat.currencyShort(store.monthToDateSpend)
    let total = max(1, store.monthToDateSpend)
    slices = store.modelCosts.map { model in
      Slice(
        name: model.name,
        cost: model.cost,
        costDisplay: KPIFormat.currencyShort(model.cost),
        shareDisplay: KPIFormat.percent(model.cost / total),
        changeDisplay: KPIFormat.signedPercent(model.change)
      )
    }
  }
}
