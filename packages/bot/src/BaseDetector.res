// QFL Base Detection — finds support levels from candle data
// A "base" is a price level where price bounced upward multiple times.
// The algorithm scans for local minimums and clusters them into base zones.

type base = {
  priceLevel: Trade.price,
  bounceCount: Config.bounceCount,
  firstSeen: Trade.timestamp,
  lastBounce: Trade.timestamp,
}

type baseDetectionResult =
  | NoBases
  | BasesFound({bases: array<base>})

// Check if a candle is a local minimum (lower low than neighbors)
let isLocalMinimum = (
  candles: array<Config.candlestick>,
  index: int,
): bool => {
  switch (candles[index - 1], candles[index], candles[index + 1]) {
  | (Some(prev), Some(curr), Some(next)) =>
    let Trade.Price(prevLow) = prev.low
    let Trade.Price(currLow) = curr.low
    let Trade.Price(nextLow) = next.low
    currLow < prevLow && currLow < nextLow
  | _ => false
  }
}

// Check if two price levels are within tolerance of each other
let pricesNear = (a: Trade.price, b: Trade.price, ~tolerancePercent: float): bool => {
  let Trade.Price(aVal) = a
  let Trade.Price(bVal) = b
  let diff = if aVal > bVal { aVal -. bVal } else { bVal -. aVal }
  let avg = (aVal +. bVal) /. 2.0
  switch avg > 0.0 {
  | true => (diff /. avg) *. 100.0 <= tolerancePercent
  | false => false
  }
}

// Cluster local minimums into base zones using reduce (Manifesto Principle 8)
// Two minimums within tolerancePercent of each other belong to the same base
let clusterMinimums = (
  minimums: array<(Trade.price, Trade.timestamp)>,
  ~tolerancePercent: float,
): array<base> => {
  minimums->Array.reduce([], (bases, (price, timestamp)) => {
    // Try to find an existing base near this price
    let matchIndex = bases->Array.findIndex(b => pricesNear(b.priceLevel, price, ~tolerancePercent))

    switch matchIndex >= 0 {
    | true =>
      // Update existing base: average the price level, increment bounce count
      bases->Array.map((b) => {
        let idx = bases->Array.findIndex(existing => existing.firstSeen == b.firstSeen)
        switch idx == matchIndex {
        | true =>
          let Trade.Price(existingLevel) = b.priceLevel
          let Trade.Price(newLevel) = price
          let Config.BounceCount(count) = b.bounceCount
          let avgLevel = (existingLevel *. Float.fromInt(count) +. newLevel) /.
            Float.fromInt(count + 1)
          {
            priceLevel: Trade.Price(avgLevel),
            bounceCount: Config.BounceCount(count + 1),
            firstSeen: b.firstSeen,
            lastBounce: timestamp,
          }
        | false => b
        }
      })
    | false =>
      // New base zone
      bases->Array.concat([{
        priceLevel: price,
        bounceCount: Config.BounceCount(1),
        firstSeen: timestamp,
        lastBounce: timestamp,
      }])
    }
  })
}

// Main base detection function
let detectBases = (
  candles: array<Config.candlestick>,
  ~minBounces: Config.bounceCount,
): baseDetectionResult => {
  let Config.BounceCount(minBounceCount) = minBounces

  if candles->Array.length < 3 {
    NoBases
  } else {
    // Find all local minimums using functional iteration (Manifesto Principle 8)
    // Skip first and last candle (need neighbors for comparison)
    let minimums =
      candles
      ->Array.mapWithIndex((candle, i) => (candle, i))
      ->Array.filterMap(((candle, i)) =>
        switch i > 0 && i < candles->Array.length - 1 && isLocalMinimum(candles, i) {
        | true => Some((candle.low, candle.openTime))
        | false => None
        }
      )

    if minimums->Array.length == 0 {
      NoBases
    } else {
      // Cluster minimums with 0.5% tolerance
      let allBases = clusterMinimums(minimums, ~tolerancePercent=0.5)

      // Filter to bases with enough bounces
      let confirmedBases =
        allBases->Array.filter(b => {
          let Config.BounceCount(count) = b.bounceCount
          count >= minBounceCount
        })

      switch confirmedBases->Array.length {
      | 0 => NoBases
      | _ =>
        // Sort by bounce count descending (strongest bases first)
        let sorted = confirmedBases->Array.toSorted((a, b) => {
          let Config.BounceCount(aCount) = a.bounceCount
          let Config.BounceCount(bCount) = b.bounceCount
          Float.fromInt(bCount - aCount)
        })
        BasesFound({bases: sorted})
      }
    }
  }
}
