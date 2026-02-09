type signal = {
  symbol: string,
  side: [#Buy | #Sell],
  price: float,
  confidence: float,
}

let scan = () => {
  Console.log("Scanning for trade signals...")
  []
}
