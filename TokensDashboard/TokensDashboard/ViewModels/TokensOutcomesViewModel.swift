/// Copyright (c) 2026 Kodeco Inc. See COPYRIGHT for details.
/// Caution: This is AI-generated code.

import Foundation

// MARK: - Detail view models

struct TokensOutcomesViewModel {
  struct Point: Identifiable {
    let name: String
    let tokensMillions: Double
    let mergedPRs: Int
    /// Above-median tokens with below-median merged PRs — the
    /// bottom-right quadrant of the chart.
    let needsCoaching: Bool
    let detailDisplay: String
    /// Human-readable quadrant label used for accessibility and coaching context.
    let quadrantLabel: String
    var id: String { name }
  }
  
  let periodLine: String
  let points: [Point]
  /// Dashed guide positions splitting the chart into quadrants.
  let medianTokensMillions: Double
  let medianPRs: Double
  /// X-axis range anchored at zero with padding so dots don't clip at the right edge.
  let tokensDomain: ClosedRange<Double>
  /// Y-axis range anchored at zero with headroom so top annotations don't clip.
  let prsDomain: ClosedRange<Double>
  
  let xAxisCaption = "Tokens consumed (millions)"
  let yAxisCaption = "Merged PRs"
  
  init(store: DeveloperOutcomeStore = DeveloperOutcomeStore()) {
    periodLine = DashboardStartDate.today.formatted(.dateTime.month(.wide).year()) + " · Month to date"
    
    let outcomes = store.developerOutcomes
    let medianTokens = Self.median(outcomes.map { $0.tokens / 1e6 })
    let medianMerged = Self.median(outcomes.map { Double($0.mergedPRs) })
    medianTokensMillions = medianTokens
    medianPRs = medianMerged
    
    let maxTokensMillions = outcomes.map { $0.tokens / 1e6 }.max() ?? 0
    // 8% right padding prevents the rightmost dot and its annotation from clipping.
    tokensDomain = 0...max(1.0, (maxTokensMillions * 1.08).rounded(.up))
    
    let maxPRs = outcomes.map { Double($0.mergedPRs) }.max() ?? 0
    // 15% top padding prevents the topmost dot's name annotation from clipping.
    prsDomain = 0...max(1.0, (maxPRs * 1.15).rounded(.up))
    
    points = outcomes.map { developer in
      let millions = developer.tokens / 1e6
      let aboveMedianTokens = millions > medianTokens
      let aboveMedianPRs = Double(developer.mergedPRs) >= medianMerged
      let quadrant: String = {
        switch (aboveMedianTokens, aboveMedianPRs) {
        case (false, true):  return "High value"
        case (true,  true):  return "High volume"
        case (true,  false): return "Needs coaching"
        case (false, false): return "Low volume"
        }
      }()
      return Point(
        name: developer.name,
        tokensMillions: millions,
        mergedPRs: developer.mergedPRs,
        needsCoaching: aboveMedianTokens && !aboveMedianPRs,
        detailDisplay: "\(KPIFormat.tokensMillionsShort(developer.tokens)) tokens · \(developer.mergedPRs) merged PRs",
        quadrantLabel: quadrant
      )
    }
  }
  
  private static func median(_ values: [Double]) -> Double {
    let sorted = values.sorted()
    guard !sorted.isEmpty else { return 0 }
    let mid = sorted.count / 2
    return sorted.count.isMultiple(of: 2) ? (sorted[mid - 1] + sorted[mid]) / 2 : sorted[mid]
  }
}
