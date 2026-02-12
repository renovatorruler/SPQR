// Thin helper for dynamic CCXT exchange construction
// CCXT uses `new ccxt[exchangeId]()` which requires dynamic class lookup
import * as ccxt from "ccxt";

export function createExchange(exchangeId) {
  const ExchangeClass = ccxt[exchangeId];
  if (!ExchangeClass) {
    throw new Error(`Unknown CCXT exchange: ${exchangeId}`);
  }
  return new ExchangeClass();
}
