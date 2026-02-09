// Strategy types and module type interface (Decision #6)
// Defines the signal type and the contract for all trading strategies.
// BaseScanner and future strategies implement this module type.

type signal =
  | Enter({side: Trade.side, symbol: Trade.symbol, qty: Trade.quantity})
  | Exit({symbol: Trade.symbol})
  | Hold

module type S = {
  let analyze: array<Trade.price> => result<signal, BotError.t>
}
