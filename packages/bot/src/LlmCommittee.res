// LLM Committee — evaluates setups via multiple LLMs and votes
//
// Uses LlmService for provider dispatch — no hard-coded provider switching here.
// Each member's provider variant determines which API backend handles the call.

type voteDecision =
  | Yes
  | No

type vote = {
  decision: voteDecision,
  confidence: Config.confidence,
  weight: Config.weight,
}

type committeeDecision =
  | Go({confidence: Config.confidence, votes: array<vote>})
  | NoGo({confidence: Config.confidence, votes: array<vote>})

let voteFromEvaluation = (evaluation: LlmShared.setupEvaluation): vote => {
  switch evaluation {
  | LlmShared.Go(_) =>
    {decision: Yes, confidence: Config.Confidence(0.6), weight: Config.Weight(1.0)}
  | LlmShared.Skip(_) =>
    {decision: No, confidence: Config.Confidence(0.6), weight: Config.Weight(1.0)}
  }
}

let evaluateMember = async (
  ~member: Config.llmMember,
  ~symbol: Trade.symbol,
  ~base: BaseDetector.base,
  ~currentPrice: Trade.price,
  ~crackPercent: Config.crackPercent,
  ~regime: LlmShared.marketRegime,
  ~candles: array<Config.candlestick>,
): result<vote, BotError.t> => {
  let config = LlmShared.configFromMember(member)
  let result = await LlmService.evaluateSetup(
    ~provider=member.provider,
    ~symbol,
    ~base,
    ~currentPrice,
    ~crackPercent,
    ~regime,
    ~candles,
    ~config,
  )
  result->Result.map(voteFromEvaluation)
}

let tallyVotes = (votes: array<vote>): (int, int, float, float) => {
  votes->Array.reduce((0, 0, 0.0, 0.0), ((yesCount, noCount, yesWeight, yesConfidence), v) => {
    switch v.decision {
    | Yes =>
      let Config.Weight(w) = v.weight
      let Config.Confidence(c) = v.confidence
      (yesCount + 1, noCount, yesWeight +. w, yesConfidence +. c)
    | No => (yesCount, noCount + 1, yesWeight, yesConfidence)
    }
  })
}

let meetsRule = (
  rule: Config.voteRule,
  ~yesCount: int,
  ~noCount: int,
  ~yesWeight: float,
): bool => {
  switch rule {
  | SimpleMajority => yesCount > noCount
  | SuperMajority({minYes: Config.MinYesVotes(minYes)}) => yesCount >= minYes
  | WeightedMajority({minWeight: Config.Weight(minWeight)}) => yesWeight >= minWeight
  }
}

let evaluateSetup = async (
  ~committee: Config.committeeConfig,
  ~symbol: Trade.symbol,
  ~base: BaseDetector.base,
  ~currentPrice: Trade.price,
  ~crackPercent: Config.crackPercent,
  ~regime: LlmShared.marketRegime,
  ~candles: array<Config.candlestick>,
): result<committeeDecision, BotError.t> => {
  // Parallel evaluation — each member's LLM call runs concurrently.
  // Latency = max(call1, call2, ...) instead of sum(call1, call2, ...).
  // LLM providers (OpenRouter, Anthropic) support concurrent requests.
  let promises = committee.members->Array.map(member => {
    evaluateMember(
      ~member,
      ~symbol,
      ~base,
      ~currentPrice,
      ~crackPercent,
      ~regime,
      ~candles,
    )
  })
  let results = await Promise.all(promises)

  let votes: array<vote> = []
  results->Array.forEachWithIndex((result, i) => {
    switch result {
    | Ok(vote) =>
      switch committee.members[i] {
      | Some(member) => votes->Array.push({...vote, weight: member.weight})
      | None => ()
      }
    | Error(e) =>
      let modelId = switch committee.members[i] {
      | Some(member) =>
        let Config.LlmModelId(id) = member.modelId
        id
      | None => "unknown"
      }
      Logger.error(`Committee member ${modelId} failed: ${BotError.toString(e)}`)
    }
  })

  let (yesCount, noCount, yesWeight, yesConfidence) = tallyVotes(votes)
  let totalYes = if yesCount > 0 { yesCount } else { 1 }
  let avgYesConfidence = yesConfidence /. Float.fromInt(totalYes)
  let Config.Confidence(minConfidence) = committee.minConfidence

  if yesCount == 0 {
    Ok(NoGo({confidence: Config.Confidence(0.0), votes}))
  } else if meetsRule(committee.rule, ~yesCount, ~noCount, ~yesWeight) && avgYesConfidence >= minConfidence {
    Ok(Go({confidence: Config.Confidence(avgYesConfidence), votes}))
  } else {
    Ok(NoGo({confidence: Config.Confidence(avgYesConfidence), votes}))
  }
}
