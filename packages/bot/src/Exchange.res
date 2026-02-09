// Exchange types and module type interface (Decision #4)
// Defines the contract for all exchange implementations.
// PaperExchange and future real exchanges implement this module type.

module type S = {
  type t

  let make: Config.exchangeConfig => result<t, BotError.t>

  let getPrice: (t, Trade.symbol) => promise<result<Trade.price, BotError.t>>

  let placeOrder: (
    t,
    ~symbol: Trade.symbol,
    ~side: Trade.side,
    ~orderType: Trade.orderType,
    ~qty: Trade.quantity,
  ) => promise<result<Trade.trade, BotError.t>>

  let getBalance: t => promise<result<Config.balance, BotError.t>>

  let getOpenPositions: t => promise<result<array<Position.position>, BotError.t>>
}
