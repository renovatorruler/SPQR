// QFL Base Detection — finds support levels from candle data
// A "base" is a price level where price bounced upward multiple times.
// The algorithm scans for local minimums and clusters them into base zones.

type base = {
  priceLevel: Trade.price,
  bounceCount: Config.bounceCount,
  firstSeen: Trade.timestamp,
  lastBounce: Trade.timestamp,
  minLevel: Trade.price,
  maxLevel: Trade.price,
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
  ~tolerancePercent: Config.tolerancePercent,
): array<base> => {
  let Config.TolerancePercent(tolerance) = tolerancePercent
  minimums->Array.reduce([], (bases, (price, timestamp)) => {
    // Try to find an existing base near this price
    let matchIndex = bases->Array.findIndex(b => pricesNear(b.priceLevel, price, ~tolerancePercent=tolerance))

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
          let Trade.Price(currentMin) = b.minLevel
          let Trade.Price(currentMax) = b.maxLevel
          let Trade.Price(priceLevel) = price
          let nextMin = if priceLevel < currentMin { priceLevel } else { currentMin }
          let nextMax = if priceLevel > currentMax { priceLevel } else { currentMax }
          {
            priceLevel: Trade.Price(avgLevel),
            bounceCount: Config.BounceCount(count + 1),
            firstSeen: b.firstSeen,
            lastBounce: timestamp,
            minLevel: Trade.Price(nextMin),
            maxLevel: Trade.Price(nextMax),
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
        minLevel: price,
        maxLevel: price,
      }])
    }
  })
}

let driftPercent = (base: base): Config.driftPercent => {
  let Trade.Price(minLevel) = base.minLevel
  let Trade.Price(maxLevel) = base.maxLevel
  let diff = if maxLevel > minLevel { maxLevel -. minLevel } else { minLevel -. maxLevel }
  if maxLevel <= 0.0 {
    Config.DriftPercent(0.0)
  } else {
    Config.DriftPercent((diff /. maxLevel) *. 100.0)
  }
}

// Main base detection function
let detectBases = (
  candles: array<Config.candlestick>,
  ~config: Config.baseFilterConfig,
): baseDetectionResult => {
  let Config.BounceCount(minBounceCount) = config.minBounces
  let Config.DriftPercent(maxDrift) = config.maxBaseDrift

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
      // Cluster minimums using configured tolerance
      let allBases = clusterMinimums(minimums, ~tolerancePercent=config.tolerance)

      // Filter to bases with enough bounces
      let confirmedBases =
        allBases->Array.filter(b => {
          let Config.BounceCount(count) = b.bounceCount
          count >= minBounceCount
        })

      // Filter out bases that drifted too far
      let stableBases =
        confirmedBases->Array.filter(b => {
          let Config.DriftPercent(drift) = driftPercent(b)
          drift <= maxDrift
        })

      switch stableBases->Array.length {
      | 0 => NoBases
      | _ =>
        // Sort by bounce count descending (strongest bases first)
        let sorted = stableBases->Array.toSorted((a, b) => {
          let Config.BounceCount(aCount) = a.bounceCount
          let Config.BounceCount(bCount) = b.bounceCount
          Float.fromInt(bCount - aCount)
        })
        BasesFound({bases: sorted})
      }
    }
  }
}
