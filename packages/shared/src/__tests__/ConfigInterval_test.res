open Vitest

// Tests for Config.interval variant and intervalToString
// Verifies the Manifesto Principle 2 upgrade from Interval(string) to proper variants

describe("Config.intervalToString", () => {
  it("converts OneMinute to '1m'", () => {
    Config.intervalToString(OneMinute)->expect->toBe("1m")
  })

  it("converts FiveMinutes to '5m'", () => {
    Config.intervalToString(FiveMinutes)->expect->toBe("5m")
  })

  it("converts FifteenMinutes to '15m'", () => {
    Config.intervalToString(FifteenMinutes)->expect->toBe("15m")
  })

  it("converts OneHour to '1h'", () => {
    Config.intervalToString(OneHour)->expect->toBe("1h")
  })

  it("converts FourHours to '4h'", () => {
    Config.intervalToString(FourHours)->expect->toBe("4h")
  })

  it("converts OneDay to '1d'", () => {
    Config.intervalToString(OneDay)->expect->toBe("1d")
  })

  it("converts OneWeek to '1w'", () => {
    Config.intervalToString(OneWeek)->expect->toBe("1w")
  })
})
