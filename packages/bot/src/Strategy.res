type params = {
  scanIntervalMs: int,
  maxPositionSize: float,
}

let defaultParams = {
  scanIntervalMs: 5000,
  maxPositionSize: 1000.0,
}

let evaluate = (_signals: array<Scanner.signal>) => {
  Console.log("Evaluating strategy...")
}
