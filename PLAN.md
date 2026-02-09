# ReScript Trading Bot + Dashboard — Project Plan

## Overview

Monorepo with three packages:
1. **shared** — Common types, error handling, logging
2. **bot** — Trading bot (ReScript compiled to Node.js)
3. **dashboard** — Web dashboard (ReScript + React + Vite)

Paper trading first. Exchange and strategy TBD. Bot persists data to SQLite; dashboard reads from it.

---

## Architecture Decisions

| # | Topic | Decision |
|---|-------|----------|
| 1 | Bot-Dashboard comms | SQLite (WAL mode) + optional WebSocket later |
| 2 | Shared types | `packages/shared` package |
| 3 | Test infra | Vitest from day one, colocated `*_test.res` files |
| 4 | Paper trading | Module type interface (`Exchange.resi` + `PaperExchange.res`) |
| 5 | Config | JSON file + typed ReScript decoder, validated at startup |
| 6 | Strategy | `Strategy.resi` interface + `BaseScanner.res` first implementation |
| 7 | Errors | Shared `BotError.t` variant, functions return `result<'a, BotError.t>` |
| 8 | Logging | Shared `Logger.res`, structured JSON, log levels |
| 9 | Test location | Colocated (`Exchange_test.res` next to `Exchange.res`) |
| 10 | Initial tests | Stubs with `test.todo()` as living spec |
| 11 | Dashboard tests | Component tests with React Testing Library |
| 12 | Test doubles | PaperExchange serves as test double |
| 13 | SQLite mode | WAL mode (`PRAGMA journal_mode=WAL`) |
| 14 | Market data | Define later — Exchange interface abstracts it |
| 15 | Build output | In-source `.res.mjs` (ReScript v12 default) |
| 16 | Memory | Bounded data structures — cap in-memory arrays, persist to SQLite |

---

## File Structure

```
gentle-cloud/
├── package.json                    # npm workspaces root
├── .gitignore
├── packages/
│   ├── shared/
│   │   ├── package.json
│   │   ├── rescript.json
│   │   └── src/
│   │       ├── Trade.res           # Trade types (record, status, side)
│   │       ├── Trade_test.res      # test.todo() stubs
│   │       ├── Position.res        # Position types
│   │       ├── Position_test.res
│   │       ├── BotError.res        # Error variant type
│   │       ├── BotError_test.res
│   │       ├── Logger.res          # Structured JSON logger
│   │       ├── Logger_test.res
│   │       └── Config.res          # Config types (shared between bot/dashboard)
│   ├── bot/
│   │   ├── package.json
│   │   ├── rescript.json
│   │   └── src/
│   │       ├── Main.res            # Entry point
│   │       ├── Exchange.resi       # Exchange module type interface
│   │       ├── PaperExchange.res   # Paper trading implementation
│   │       ├── PaperExchange_test.res
│   │       ├── Strategy.resi       # Strategy module type interface
│   │       ├── BaseScanner.res     # First strategy implementation
│   │       ├── BaseScanner_test.res
│   │       ├── BotConfig.res       # Bot-specific config (JSON loader + decoder)
│   │       └── BotConfig_test.res
│   └── dashboard/
│       ├── package.json
│       ├── rescript.json
│       ├── index.html
│       ├── vite.config.mjs
│       └── src/
│           ├── App.res             # Root React component
│           ├── App_test.res
│           ├── Dashboard.res       # Overview: P&L, positions
│           ├── Dashboard_test.res
│           ├── TradeHistory.res    # Trade history table
│           └── TradeHistory_test.res
```

---

## Implementation Steps

### Step 1: Clean the directory
- Remove all existing files (keeping `.git`)

### Step 2: Create monorepo root
- `package.json` with npm workspaces: `"packages/*"`
- `.gitignore` for Node.js, ReScript (`*.res.mjs`), SQLite, config

### Step 3: Set up `packages/shared`
- ReScript v12, ES modules, no JSX
- Types: `Trade.res`, `Position.res`, `Config.res`
- `BotError.res` — variant type with `ExchangeError`, `InsufficientBalance`, `RateLimited`, `NetworkError`, `ConfigError`
- `Logger.res` — structured JSON logger with `Debug`, `Info`, `Trade`, `Error` levels
- Colocated test stubs with `test.todo()` for each module

### Step 4: Set up `packages/bot`
- ReScript v12, ES modules, no JSX
- Depends on `@spqr/shared`
- `Exchange.resi` — module type defining exchange operations (getPrice, placeOrder, getBalance, etc.)
- `PaperExchange.res` — in-memory paper trading implementation with bounded trade history
- `Strategy.resi` — module type defining strategy interface (analyze, shouldEnter, shouldExit)
- `BaseScanner.res` — placeholder implementation of Strategy
- `BotConfig.res` — loads `config.json`, decodes with typed validation, fails fast on errors
- Colocated test stubs

### Step 5: Set up `packages/dashboard`
- ReScript v12 + React, JSX v4, Vite
- Depends on `@spqr/shared`
- `App.res` — root component with basic routing
- `Dashboard.res` — overview page (P&L, active positions)
- `TradeHistory.res` — trade history table
- Colocated test stubs

### Step 6: Install dependencies
- `npm install` from root
- Key deps: `rescript`, `@rescript/react`, `react`, `react-dom`, `vite`, `vitest`, `better-sqlite3`

### Step 7: Verify builds
- `npm run res:build` in each package
- `npm run test` in each package (all todos should be pending)
- Dashboard dev server starts

---

## Key Design Principles

1. **DRY**: All shared types live in `packages/shared`. No type duplication.
2. **Explicit errors**: `result<'a, BotError.t>` everywhere. No exceptions for expected failures.
3. **Bounded memory**: In-memory arrays capped. Overflow persists to SQLite.
4. **Swappable implementations**: Exchange and Strategy are module type interfaces. Paper/live, scanner/other strategies swap without changing consuming code.
5. **Tests as spec**: `test.todo()` stubs define what needs testing before code is written.
6. **Fail fast**: Config validated at startup. Bad config = immediate crash with clear error.
