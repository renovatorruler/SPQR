type kind = DEX | CEX

type config = {
  name: string,
  kind: kind,
  apiKey: option<string>,
  apiSecret: option<string>,
}

let make = (~name, ~kind, ~apiKey=?, ~apiSecret=?) => {
  name,
  kind,
  apiKey,
  apiSecret,
}
