open Vitest

// Pure logic tests for Dashboard.res
// Tests the variant-to-string/class formatters — no DOM needed

describe("Dashboard.botStatusToString", () => {
  it("returns 'Online' for Online", () => {
    Dashboard.botStatusToString(Online)->expect->toBe("Online")
  })

  it("returns 'Offline' for Offline", () => {
    Dashboard.botStatusToString(Offline)->expect->toBe("Offline")
  })

  it("returns 'Error: <msg>' for BotError", () => {
    Dashboard.botStatusToString(BotError({message: "connection lost"}))->expect->toBe(
      "Error: connection lost",
    )
  })

  it("handles empty error message", () => {
    Dashboard.botStatusToString(BotError({message: ""}))->expect->toBe("Error: ")
  })
})

describe("Dashboard.botStatusColor", () => {
  it("maps Online to #primary", () => {
    Dashboard.botStatusColor(Online)->expect->toBe(#primary)
  })

  it("maps Offline to #onsurfacevariant", () => {
    Dashboard.botStatusColor(Offline)->expect->toBe(#onsurfacevariant)
  })

  it("maps BotError to #error", () => {
    Dashboard.botStatusColor(BotError({message: "anything"}))->expect->toBe(#error)
  })
})

describe("Dashboard.botStatusDotClass", () => {
  it("maps Online to online dot class", () => {
    Dashboard.botStatusDotClass(Online)->expect->toBe("spqr-status-dot spqr-status-dot--online")
  })

  it("maps Offline to offline dot class", () => {
    Dashboard.botStatusDotClass(Offline)->expect->toBe("spqr-status-dot spqr-status-dot--offline")
  })

  it("maps BotError to error dot class", () => {
    Dashboard.botStatusDotClass(BotError({message: "oops"}))->expect->toBe(
      "spqr-status-dot spqr-status-dot--error",
    )
  })
})
