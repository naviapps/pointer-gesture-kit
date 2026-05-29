/// Normalizes gesture trace endpoints for observation.
enum GestureTraceEndpointNormalizer {
  /// Returns endpoints sized to the number of recognized directions when points are available.
  static func normalizedEndpoints(
    endpoints: [GesturePoint],
    recognizedDirectionCount: Int,
    publishedRawPoints: [GesturePoint]
  ) -> [GesturePoint] {
    guard recognizedDirectionCount >= 0 else { return [] }
    guard recognizedDirectionCount < Int.max else { return endpoints }

    let expectedEndpointCount = recognizedDirectionCount + 1
    let trimmedPoints = trimmed(
      endpoints,
      toExpectedEndpointCount: expectedEndpointCount
    )
    return padded(
      trimmedPoints,
      toExpectedEndpointCount: expectedEndpointCount,
      publishedRawPoints: publishedRawPoints
    )
  }

  private static func trimmed(
    _ endpoints: [GesturePoint],
    toExpectedEndpointCount expectedEndpointCount: Int
  ) -> [GesturePoint] {
    guard endpoints.count > expectedEndpointCount else { return endpoints }
    guard expectedEndpointCount > 1 else {
      return Array(endpoints.prefix(expectedEndpointCount))
    }

    var trimmed = Array(endpoints.prefix(expectedEndpointCount - 1))
    if let last = endpoints.last {
      trimmed.append(last)
    }
    return trimmed
  }

  private static func padded(
    _ endpoints: [GesturePoint],
    toExpectedEndpointCount expectedEndpointCount: Int,
    publishedRawPoints: [GesturePoint]
  ) -> [GesturePoint] {
    var padded = endpoints
    guard padded.count < expectedEndpointCount else { return padded }

    let publishedRawPointCandidates = remainingRawPoints(
      afterMatching: padded,
      in: publishedRawPoints
    )
    var iterator = publishedRawPointCandidates.makeIterator()
    while padded.count < expectedEndpointCount, let next = iterator.next() {
      if let last = padded.last, last == next {
        continue
      }
      padded.append(next)
    }

    guard padded.count < expectedEndpointCount,
      let fillerPoint = padded.last ?? publishedRawPoints.last
    else {
      return padded
    }

    padded.append(
      contentsOf: Array(
        repeating: fillerPoint,
        count: expectedEndpointCount - padded.count
      ))

    return padded
  }

  private static func remainingRawPoints(
    afterMatching endpoints: [GesturePoint],
    in publishedRawPoints: [GesturePoint]
  ) -> ArraySlice<GesturePoint> {
    var searchStartIndex = publishedRawPoints.startIndex

    for point in endpoints {
      guard let matchedIndex = publishedRawPoints[searchStartIndex...].firstIndex(of: point) else {
        return publishedRawPoints[searchStartIndex...]
      }

      searchStartIndex = publishedRawPoints.index(after: matchedIndex)
    }

    return publishedRawPoints[searchStartIndex...]
  }
}
