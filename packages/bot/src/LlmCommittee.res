// LLM Committee — evaluates setups via multiple LLMs and votes

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

let voteFromEvaluation = (evaluation: LlmEvaluator.setupEvaluation): vote => {
  switch evaluation {
  | LlmEvaluator.Go(_) =>
    {decision: Yes, confidence: Config.Confidence(0.6), weight: Config.Weight(1.0)}
  | LlmEvaluator.Skip(_) =>
    {decision: No, confidence: Config.Confidence(0.6), weight: Config.Weight(1.0)}
  }
}

let evaluateMember = async (
  ~member: Config.llmMember,
  ~symbol: Trade.symbol,
  ~base: BaseDetector.base,
  ~currentPrice: Trade.price,
  ~crackPercent: Config.crackPercent,
  ~regime: LlmEvaluator.marketRegime,
  ~candles: array<Config.candlestick>,
): result<vote, BotError.t> => {
  switch member.provider {
  | Config.OpenRouter =>
    let result = await OpenRouterEvaluator.evaluateSetup(
      ~member,
      ~symbol,
      ~base,
      ~currentPrice,
      ~crackPercent,
      ~regime,
      ~candles,
    )
    result->Result.map(voteFromEvaluation)
  | Config.Anthropic =>
    let Config.LlmModelId(modelId) = member.modelId
    let config: Config.llmConfig = {
      apiKey: member.apiKey,
      model: Config.LlmModel(modelId),
      regimeCheckIntervalMs: Config.IntervalMs(60000),
      evaluateSetups: true,
    }
    let result = await LlmEvaluator.evaluateSetup(
      ~symbol,
      ~base,
      ~currentPrice,
      ~crackPercent,
      ~regime,
      ~candles,
      ~config,
    )
    result->Result.map(voteFromEvaluation)
  | _ =>
    Error(BotError.LlmError(ApiCallFailed({message: "LLM provider not implemented"})))
  }
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
  ~regime: LlmEvaluator.marketRegime,
  ~candles: array<Config.candlestick>,
): result<committeeDecision, BotError.t> => {
  let votes: array<vote> = []

  // Sequential async for rate-limited API calls.
  for i in 0 to committee.members->Array.length - 1 {
    switch committee.members[i] {
    | Some(member) =>
      let result = await evaluateMember(
        ~member,
        ~symbol,
        ~base,
        ~currentPrice,
        ~crackPercent,
        ~regime,
        ~candles,
      )
      switch result {
      | Ok(vote) => votes->Array.push({...vote, weight: member.weight})
      | Error(_) => ()
      }
    | None => ()
    }
  }

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
