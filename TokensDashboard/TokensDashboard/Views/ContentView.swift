/// Copyright (c) 2026 Kodeco Inc. See COPYRIGHT for details.
/// Caution: This is AI-generated code.

import SwiftUI

@main struct MyApp: App {
  var body: some Scene {
    WindowGroup {
      ContentView()
    }
  }
}

/// Root of the app: the summary brief, drilling into the cost-by-model graph.
struct ContentView: View {
  var body: some View {
    NavigationStack {
      SummaryView()
    }
  }
}

#Preview {
  ContentView()
}
