import XCTest

@testable import PointerGestureKit

final class GestureTraceEndpointNormalizerTests: XCTestCase {
  func testReturnsEndpointsWhenTheyAlreadyMatchRecognizedDirectionCount() {
    let endpoints: [GesturePoint] = [
      GesturePoint(x: 0, y: 0),
      GesturePoint(x: 10, y: 0),
      GesturePoint(x: 10, y: 10),
    ]
    let publishedRawPoints: [GesturePoint] = [
      GesturePoint(x: 100, y: 100),
      GesturePoint(x: 200, y: 200),
    ]

    let result = GestureTraceEndpointNormalizer.normalizedEndpoints(
      endpoints: endpoints,
      recognizedDirectionCount: 2,
      publishedRawPoints: publishedRawPoints
    )

    XCTAssertEqual(result, endpoints)
  }

  func testTrimsExcessPointsKeepingPrefixAndLastPoint() {
    let recognizedDirectionCount = 2
    let endpoints: [GesturePoint] = [
      GesturePoint(x: 0, y: 0),
      GesturePoint(x: 10, y: 0),
      GesturePoint(x: 20, y: 0),
      GesturePoint(x: 20, y: 10),
      GesturePoint(x: 20, y: 20),
    ]

    let result = GestureTraceEndpointNormalizer.normalizedEndpoints(
      endpoints: endpoints,
      recognizedDirectionCount: recognizedDirectionCount,
      publishedRawPoints: endpoints
    )

    XCTAssertEqual(result.count, recognizedDirectionCount + 1)
    XCTAssertEqual(result[0], endpoints[0])
    XCTAssertEqual(result[1], endpoints[1])
    XCTAssertEqual(result[2], endpoints.last)
  }

  func testTrimsExcessPointsForEmptyDirectionsToFirstPoint() {
    let endpoints: [GesturePoint] = [
      GesturePoint(x: 0, y: 0),
      GesturePoint(x: 10, y: 0),
    ]

    let result = GestureTraceEndpointNormalizer.normalizedEndpoints(
      endpoints: endpoints,
      recognizedDirectionCount: 0,
      publishedRawPoints: endpoints
    )

    XCTAssertEqual(result, [endpoints[0]])
  }

  func testFillsMissingPointsFromPublishedRawPointsSkippingDuplicates() {
    let recognizedDirectionCount = 2
    let endpoints: [GesturePoint] = [GesturePoint(x: 0, y: 0)]
    let publishedRawPoints: [GesturePoint] = [
      GesturePoint(x: 0, y: 0),
      GesturePoint(x: 0, y: 0),
      GesturePoint(x: 10, y: 0),
      GesturePoint(x: 10, y: 10),
    ]

    let result = GestureTraceEndpointNormalizer.normalizedEndpoints(
      endpoints: endpoints,
      recognizedDirectionCount: recognizedDirectionCount,
      publishedRawPoints: publishedRawPoints
    )

    XCTAssertEqual(result, [publishedRawPoints[0], publishedRawPoints[2], publishedRawPoints[3]])
  }

  func testFillsMissingPointsOnlyAfterLastEndpoint() {
    let recognizedDirectionCount = 2
    let endpoints: [GesturePoint] = [GesturePoint(x: 10, y: 0)]
    let publishedRawPoints: [GesturePoint] = [
      GesturePoint(x: 0, y: 0),
      GesturePoint(x: 10, y: 0),
      GesturePoint(x: 10, y: 10),
      GesturePoint(x: 20, y: 10),
    ]

    let result = GestureTraceEndpointNormalizer.normalizedEndpoints(
      endpoints: endpoints,
      recognizedDirectionCount: recognizedDirectionCount,
      publishedRawPoints: publishedRawPoints
    )

    XCTAssertEqual(result, [publishedRawPoints[1], publishedRawPoints[2], publishedRawPoints[3]])
  }

  func testFillsMissingPointsAfterMatchedEndpointSequence() {
    let recognizedDirectionCount = 3
    let endpoints: [GesturePoint] = [
      GesturePoint(x: 0, y: 0),
      GesturePoint(x: 10, y: 0),
    ]
    let publishedRawPoints: [GesturePoint] = [
      GesturePoint(x: 0, y: 0),
      GesturePoint(x: 10, y: 0),
      GesturePoint(x: 0, y: 0),
      GesturePoint(x: 10, y: 0),
      GesturePoint(x: 10, y: 10),
    ]

    let result = GestureTraceEndpointNormalizer.normalizedEndpoints(
      endpoints: endpoints,
      recognizedDirectionCount: recognizedDirectionCount,
      publishedRawPoints: publishedRawPoints
    )

    XCTAssertEqual(
      result,
      [publishedRawPoints[0], publishedRawPoints[1], publishedRawPoints[2], publishedRawPoints[3]]
    )
  }

  func testFillsMissingPointsAfterPartialEndpointMatch() {
    let recognizedDirectionCount = 3
    let endpoints: [GesturePoint] = [
      GesturePoint(x: 0, y: 0),
      GesturePoint(x: 99, y: 99),
    ]
    let publishedRawPoints: [GesturePoint] = [
      GesturePoint(x: 0, y: 0),
      GesturePoint(x: 10, y: 0),
      GesturePoint(x: 20, y: 0),
    ]

    let result = GestureTraceEndpointNormalizer.normalizedEndpoints(
      endpoints: endpoints,
      recognizedDirectionCount: recognizedDirectionCount,
      publishedRawPoints: publishedRawPoints
    )

    XCTAssertEqual(
      result,
      [endpoints[0], endpoints[1], publishedRawPoints[1], publishedRawPoints[2]]
    )
  }

  func testEmptyEndpointsFallsBackToFirstRawPoint() {
    let publishedRawPoints: [GesturePoint] = [GesturePoint(x: 5, y: 5)]

    let result = GestureTraceEndpointNormalizer.normalizedEndpoints(
      endpoints: [],
      recognizedDirectionCount: 0,
      publishedRawPoints: publishedRawPoints
    )

    XCTAssertEqual(result, [publishedRawPoints[0]])
  }

  func testRepeatsLastAvailablePointWhenPublishedRawPointsDoNotFillTarget() {
    let recognizedDirectionCount = 2
    let endpoints: [GesturePoint] = [GesturePoint(x: 0, y: 0)]
    let publishedRawPoints: [GesturePoint] = [
      GesturePoint(x: 0, y: 0),
      GesturePoint(x: 10, y: 0),
    ]

    let result = GestureTraceEndpointNormalizer.normalizedEndpoints(
      endpoints: endpoints,
      recognizedDirectionCount: recognizedDirectionCount,
      publishedRawPoints: publishedRawPoints
    )

    XCTAssertEqual(result, [publishedRawPoints[0], publishedRawPoints[1], publishedRawPoints[1]])
  }

  func testRepeatsLastEndpointWhenRawPointsAreUnavailable() {
    let endpoints: [GesturePoint] = [
      GesturePoint(x: 0, y: 0),
      GesturePoint(x: 10, y: 0),
    ]

    let result = GestureTraceEndpointNormalizer.normalizedEndpoints(
      endpoints: endpoints,
      recognizedDirectionCount: 3,
      publishedRawPoints: []
    )

    XCTAssertEqual(result, [endpoints[0], endpoints[1], endpoints[1], endpoints[1]])
  }

  func testReturnsEmptyWhenNoPointsAreAvailable() {
    let result = GestureTraceEndpointNormalizer.normalizedEndpoints(
      endpoints: [],
      recognizedDirectionCount: 1,
      publishedRawPoints: []
    )

    XCTAssertTrue(result.isEmpty)
  }

  func testReturnsEmptyForNegativeRecognizedDirectionCount() {
    let result = GestureTraceEndpointNormalizer.normalizedEndpoints(
      endpoints: [GesturePoint(x: 0, y: 0)],
      recognizedDirectionCount: -1,
      publishedRawPoints: [GesturePoint(x: 0, y: 0)]
    )

    XCTAssertTrue(result.isEmpty)
  }

  func testLeavesEndpointsUnchangedWhenRecognizedDirectionCountCannotFitEndpointCount() {
    let endpoints = [GesturePoint(x: 0, y: 0), GesturePoint(x: 10, y: 0)]

    let result = GestureTraceEndpointNormalizer.normalizedEndpoints(
      endpoints: endpoints,
      recognizedDirectionCount: Int.max,
      publishedRawPoints: endpoints
    )

    XCTAssertEqual(result, endpoints)
  }
}
