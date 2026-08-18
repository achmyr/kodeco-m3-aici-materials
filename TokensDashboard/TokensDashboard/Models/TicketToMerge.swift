/// Copyright (c) 2026 Kodeco Inc. See COPYRIGHT for details.
/// Caution: This is AI-generated code.

import Foundation

// MARK: - Model layer

/// Cohort of developers grouped by how heavily they lean on AI tooling.
enum AIUsageCohort: String, CaseIterable {
  case heavyUsers = "Heavy AI users"
  case lightUsers = "Light AI users"
}

/// Average production time for one cohort in one month: days from ticket
/// opened to pull request merged.
struct TicketToMergeSample: Identifiable {
  let month: Date
  let cohort: AIUsageCohort
  /// Average days from ticket to merge — lower is better.
  let avgDays: Double
  
  var id: String { "\(cohort.rawValue)·\(month.timeIntervalSinceReferenceDate)" }
}

// MARK: - Data source

/// Source of truth for the cycle-time graph: fixed mock data for the five
/// months ending at May 1, 2026 (`DashboardStartDate.today`), so every screen
/// shows the same numbers and previews render identically on every run.
struct TicketToMergeStore {
  let samples: [TicketToMergeSample] = {
    let heavyAIUsageDaysByMonth: [Double] = [6.1, 5.4, 4.5, 4.1, 3.8]
    let lightAIUsageDaysByMonth: [Double] = [6.3, 6.0, 6.2, 5.9, 6.1]
    return (0..<heavyAIUsageDaysByMonth.count).flatMap { offset -> [TicketToMergeSample] in
      let month = DateComponents(calendar: .current, year: 2026, month: offset + 1, day: 1).date!
      return [
        TicketToMergeSample(month: month, cohort: .heavyUsers, avgDays: heavyAIUsageDaysByMonth[offset]),
        TicketToMergeSample(month: month, cohort: .lightUsers, avgDays: lightAIUsageDaysByMonth[offset]),
      ]
    }
  }()
}
