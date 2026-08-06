import XCTest
@testable import TokensDashboard

final class CostbyModelTests: XCTestCase {
  func testModelCostStoreSums() {
    let store = ModelCostStore()
    XCTAssertEqual(store.modelCosts.count, 5)
    XCTAssertEqual(store.monthToDateSpend, 204_100)
    XCTAssertEqual(store.monthToDateTokens, 32_700_000_000)
  }

  func testModelCostIdentifiable() {
    let m = ModelCost(name: "Test", cost: 1.0, tokens: 2.0, change: 0.1, requests: 10)
    XCTAssertEqual(m.id, "Test")
  }

  func testRequestsColumnRefreshesOffMainThread() {
    let viewModel = CostByModelViewModel()
    XCTAssertEqual(viewModel.slices.count, 5)

    let expectation = expectation(description: "requests column refreshed")
    // Exercises CostByModelViewModel.refreshRequestsColumn(), which republishes
    // `slices` from a background queue.
    viewModel.refreshRequestsColumn()
    DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
      expectation.fulfill()
    }
    wait(for: [expectation], timeout: 1)

    XCTAssertEqual(viewModel.slices.first?.requestsDisplay, "412000")
  }
}
