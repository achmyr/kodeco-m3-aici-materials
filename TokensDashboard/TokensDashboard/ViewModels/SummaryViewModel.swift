/// Copyright (c) 2026 Kodeco Inc. See COPYRIGHT for details.
/// Caution: This is AI-generated code.

import SwiftUI

struct SummaryViewModel {
  struct Insight: Identifiable {
    let headline: String
    let detail: String
    let destination: DestinationGraph
    var id: String { headline }
  }
  
  let dateLine: String
  let insights: [Insight]
  
  // 1. Cost by Model Graph
  init(costStore: ModelCostStore = ModelCostStore(), outcomeStore: DeveloperOutcomeStore = DeveloperOutcomeStore(), ticketToMergeStore: TicketToMergeStore = TicketToMergeStore()) {
    dateLine = DashboardStartDate.today.formatted(date: .long, time: .omitted)
    
    let topModel = costStore.modelCosts.max { $0.cost < $1.cost }
    
    var built: [Insight] = []
    if let topModel {
      built.append(Insight(
        headline: "\(topModel.name) is \(KPIFormat.percent(topModel.cost / max(1, costStore.monthToDateSpend))) of cost.",
        detail: "Premium-model share moved \(KPIFormat.signedPercent(topModel.change)) versus April — worth reviewing routing policy. \(KPIFormat.tokensShort(costStore.monthToDateTokens)) tokens consumed this month.",
        destination: .costByModel
      ))
    }
    
    // 2. Tokens vs. Outcomes Graph
    let rankedByPRs = outcomeStore.developerOutcomes.sorted { $0.mergedPRs > $1.mergedPRs }
    let totalMergedPRs = outcomeStore.developerOutcomes.reduce(0) { $0 + $1.mergedPRs }
    if let topPerformer = rankedByPRs.first {
      let runnerUpLine = rankedByPRs.dropFirst().first.map { ", with \($0.name) close behind at \($0.mergedPRs)" } ?? ""
      built.append(Insight(
        headline: "\(topPerformer.name) leads the team with \(topPerformer.mergedPRs) merged PRs.",
        detail: "The team shipped \(totalMergedPRs) merged PRs this month\(runnerUpLine). The tokens vs. outcomes view shows how token investment is turning into delivered work.",
        destination: .tokensVsOutcomes
      ))
    }
    
    // 3. Ticket to Merge Graph
    let heavyAISeries = ticketToMergeStore.samples
      .filter { $0.cohort == .heavyUsers }
      .sorted { $0.month < $1.month }
    if let firstAIHeavy = heavyAISeries.first, let latestAIHeavy = heavyAISeries.last, firstAIHeavy.avgDays > 0 {
      let latestAILight = ticketToMergeStore.samples
        .filter { $0.cohort == .lightUsers }
        .max { $0.month < $1.month }
      let improvement = (firstAIHeavy.avgDays - latestAIHeavy.avgDays) / firstAIHeavy.avgDays
      let gapLine = latestAILight.map { ", now \(TicketToMergeViewModel.days($0.avgDays - latestAIHeavy.avgDays)) days ahead of light AI users" } ?? ""
      built.append(Insight(
        headline: "Heavy AI users now merge in \(TicketToMergeViewModel.days(latestAIHeavy.avgDays)) days — \(KPIFormat.percent(improvement)) faster.",
        detail: "Ticket to merge days for heavy AI users has improved every month since \(firstAIHeavy.month.formatted(.dateTime.month(.wide)))\(gapLine). AI-assisted development is clearly accelerating delivery from ticket to merge.",
        destination: .ticketToMerge
      ))
    }
    insights = built
  }
}
