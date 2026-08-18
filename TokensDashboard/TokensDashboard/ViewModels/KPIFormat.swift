/// Copyright (c) 2026 Kodeco Inc. See COPYRIGHT for details.
/// Caution: This is AI-generated code.

// MARK: - Display formatting shared by the view models
import Foundation

enum KPIFormat {
  /// "$7.7K", "$204.1K" — assumes values in the thousands.
  static func currencyShort(_ value: Double) -> String {
    "$\(trimmed(value / 1_000))K"
  }
  
  /// "32.7B" — assumes values in the billions.
  static func tokensShort(_ value: Double) -> String {
    "\(trimmed(value / 1e9))B"
  }
  
  /// "+23%", "-4%"
  static func signedPercent(_ fraction: Double) -> String {
    let sign = fraction >= 0 ? "+" : "-"
    return "\(sign)\(trimmed(abs(fraction) * 100))%"
  }
  
  /// "79%"
  static func percent(_ fraction: Double) -> String {
    "\(Int((fraction * 100).rounded()))%"
  }
  
  private static func trimmed(_ value: Double) -> String {
    value.formatted(.number.precision(.fractionLength(0...1)))
  }
  
  /// "6.8M" — assumes values in the millions.
  static func tokensMillionsShort(_ value: Double) -> String {
    "\((value / 1e6).formatted(.number.precision(.fractionLength(0...1))))M"
  }
}
