open Vitest

// -- helpers ------------------------------------------------------------------

let yesVote = (~confidence=Config.Confidence(0.8), ~weight=Config.Weight(1.0), ()): LlmCommittee.vote => {
  decision: Yes,
  confidence,
  weight,
}

let noVote = (~confidence=Config.Confidence(0.5), ~weight=Config.Weight(1.0), ()): LlmCommittee.vote => {
  decision: No,
  confidence,
  weight,
}

// -- tests --------------------------------------------------------------------

describe("LlmCommittee", () => {
  // ---------------------------------------------------------------------------
  // voteFromEvaluation
  // ---------------------------------------------------------------------------
  describe("voteFromEvaluation", () => {
    it("Go evaluation produces a Yes vote", () => {
      let vote = LlmCommittee.voteFromEvaluation(LlmEvaluator.Go({reasoning: "looks good"}))
      switch vote.decision {
      | Yes => expect(true)->toBe(true)
      | No => expect(true)->toBe(false)
      }
    })

    it("Skip evaluation produces a No vote", () => {
      let vote = LlmCommittee.voteFromEvaluation(LlmEvaluator.Skip({reasoning: "too risky"}))
      switch vote.decision {
      | No => expect(true)->toBe(true)
      | Yes => expect(true)->toBe(false)
      }
    })

    it("assigns default confidence of 0.6", () => {
      let vote = LlmCommittee.voteFromEvaluation(LlmEvaluator.Go({reasoning: "ok"}))
      let Config.Confidence(c) = vote.confidence
      expect(c)->toBeCloseTo(0.6)
    })

    it("assigns default weight of 1.0", () => {
      let vote = LlmCommittee.voteFromEvaluation(LlmEvaluator.Go({reasoning: "ok"}))
      let Config.Weight(w) = vote.weight
      expect(w)->toBeCloseTo(1.0)
    })
  })

  // ---------------------------------------------------------------------------
  // tallyVotes
  // ---------------------------------------------------------------------------
  describe("tallyVotes", () => {
    it("returns zeros for empty votes array", () => {
      let (yesCount, noCount, yesWeight, yesConf) = LlmCommittee.tallyVotes([])
      expect(yesCount)->toBe(0)
      expect(noCount)->toBe(0)
      expect(yesWeight)->toBeCloseTo(0.0)
      expect(yesConf)->toBeCloseTo(0.0)
    })

    it("tallies all Yes votes correctly", () => {
      let votes = [
        yesVote(~confidence=Config.Confidence(0.8), ~weight=Config.Weight(1.0), ()),
        yesVote(~confidence=Config.Confidence(0.9), ~weight=Config.Weight(1.0), ()),
      ]
      let (yesCount, noCount, yesWeight, yesConf) = LlmCommittee.tallyVotes(votes)
      expect(yesCount)->toBe(2)
      expect(noCount)->toBe(0)
      expect(yesWeight)->toBeCloseTo(2.0)
      expect(yesConf)->toBeCloseTo(1.7)
    })

    it("tallies all No votes correctly", () => {
      let votes = [
        noVote(~confidence=Config.Confidence(0.5), ~weight=Config.Weight(1.0), ()),
        noVote(~confidence=Config.Confidence(0.6), ~weight=Config.Weight(1.0), ()),
      ]
      let (yesCount, noCount, yesWeight, yesConf) = LlmCommittee.tallyVotes(votes)
      expect(yesCount)->toBe(0)
      expect(noCount)->toBe(2)
      expect(yesWeight)->toBeCloseTo(0.0)
      expect(yesConf)->toBeCloseTo(0.0)
    })

    it("tallies mixed Yes and No votes correctly", () => {
      let votes = [
        yesVote(~confidence=Config.Confidence(0.8), ~weight=Config.Weight(1.0), ()),
        noVote(~confidence=Config.Confidence(0.5), ~weight=Config.Weight(1.0), ()),
        yesVote(~confidence=Config.Confidence(0.7), ~weight=Config.Weight(1.0), ()),
      ]
      let (yesCount, noCount, yesWeight, yesConf) = LlmCommittee.tallyVotes(votes)
      expect(yesCount)->toBe(2)
      expect(noCount)->toBe(1)
      expect(yesWeight)->toBeCloseTo(2.0)
      expect(yesConf)->toBeCloseTo(1.5) // 0.8 + 0.7
    })

    it("respects different weights per vote", () => {
      let votes = [
        yesVote(~confidence=Config.Confidence(0.9), ~weight=Config.Weight(2.5), ()),
        yesVote(~confidence=Config.Confidence(0.6), ~weight=Config.Weight(0.5), ()),
        noVote(~confidence=Config.Confidence(0.4), ~weight=Config.Weight(3.0), ()),
      ]
      let (yesCount, noCount, yesWeight, yesConf) = LlmCommittee.tallyVotes(votes)
      expect(yesCount)->toBe(2)
      expect(noCount)->toBe(1)
      expect(yesWeight)->toBeCloseTo(3.0) // 2.5 + 0.5
      expect(yesConf)->toBeCloseTo(1.5) // 0.9 + 0.6
    })

    it("handles a single vote", () => {
      let votes = [yesVote(~confidence=Config.Confidence(0.75), ~weight=Config.Weight(1.5), ())]
      let (yesCount, noCount, yesWeight, yesConf) = LlmCommittee.tallyVotes(votes)
      expect(yesCount)->toBe(1)
      expect(noCount)->toBe(0)
      expect(yesWeight)->toBeCloseTo(1.5)
      expect(yesConf)->toBeCloseTo(0.75)
    })
  })

  // ---------------------------------------------------------------------------
  // meetsRule
  // ---------------------------------------------------------------------------
  describe("meetsRule", () => {
    // -- SimpleMajority -------------------------------------------------------
    it("SimpleMajority: returns true when more yes than no", () => {
      let result = LlmCommittee.meetsRule(SimpleMajority, ~yesCount=3, ~noCount=1, ~yesWeight=3.0)
      expect(result)->toBe(true)
    })

    it("SimpleMajority: returns false when yes equals no", () => {
      let result = LlmCommittee.meetsRule(SimpleMajority, ~yesCount=2, ~noCount=2, ~yesWeight=2.0)
      expect(result)->toBe(false)
    })

    it("SimpleMajority: returns false when fewer yes than no", () => {
      let result = LlmCommittee.meetsRule(SimpleMajority, ~yesCount=1, ~noCount=3, ~yesWeight=1.0)
      expect(result)->toBe(false)
    })

    // -- SuperMajority --------------------------------------------------------
    it("SuperMajority: returns true when yesCount meets minYes", () => {
      let result = LlmCommittee.meetsRule(
        SuperMajority({minYes: Config.MinYesVotes(3)}),
        ~yesCount=3,
        ~noCount=1,
        ~yesWeight=3.0,
      )
      expect(result)->toBe(true)
    })

    it("SuperMajority: returns false when yesCount is below minYes", () => {
      let result = LlmCommittee.meetsRule(
        SuperMajority({minYes: Config.MinYesVotes(3)}),
        ~yesCount=2,
        ~noCount=1,
        ~yesWeight=2.0,
      )
      expect(result)->toBe(false)
    })

    // -- WeightedMajority -----------------------------------------------------
    it("WeightedMajority: returns true when yesWeight meets minWeight", () => {
      let result = LlmCommittee.meetsRule(
        WeightedMajority({minWeight: Config.Weight(2.5)}),
        ~yesCount=2,
        ~noCount=1,
        ~yesWeight=3.0,
      )
      expect(result)->toBe(true)
    })

    it("WeightedMajority: returns false when yesWeight is below minWeight", () => {
      let result = LlmCommittee.meetsRule(
        WeightedMajority({minWeight: Config.Weight(5.0)}),
        ~yesCount=2,
        ~noCount=1,
        ~yesWeight=3.0,
      )
      expect(result)->toBe(false)
    })
  })
})
