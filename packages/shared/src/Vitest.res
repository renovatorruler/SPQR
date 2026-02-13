// Vitest bindings for ReScript
// Covers describe, it/test, expect + matchers, beforeEach/afterEach

type expect<'a>
type assertion

@module("vitest") external describe: (string, unit => unit) => unit = "describe"
@module("vitest") external test: (string, unit => unit) => unit = "test"
@module("vitest") external testAsync: (string, unit => promise<unit>) => unit = "test"
@module("vitest") external it: (string, unit => unit) => unit = "it"
@module("vitest") external itAsync: (string, unit => promise<unit>) => unit = "it"
@module("vitest") external beforeEach: (unit => unit) => unit = "beforeEach"
@module("vitest") external beforeEachAsync: (unit => promise<unit>) => unit = "beforeEach"
@module("vitest") external afterEach: (unit => unit) => unit = "afterEach"
@module("vitest") external afterEachAsync: (unit => promise<unit>) => unit = "afterEach"
@module("vitest") external beforeAll: (unit => unit) => unit = "beforeAll"
@module("vitest") external afterAll: (unit => unit) => unit = "afterAll"

@module("vitest") external expect: 'a => expect<'a> = "expect"

// Matchers
@send external toBe: (expect<'a>, 'a) => unit = "toBe"
@send external toEqual: (expect<'a>, 'a) => unit = "toEqual"
@send external toBeDefined: expect<'a> => unit = "toBeDefined"
@send external toBeUndefined: expect<'a> => unit = "toBeUndefined"
@send external toBeTruthy: expect<'a> => unit = "toBeTruthy"
@send external toBeFalsy: expect<'a> => unit = "toBeFalsy"
@send external toBeGreaterThan: (expect<'a>, 'a) => unit = "toBeGreaterThan"
@send external toBeGreaterThanOrEqual: (expect<'a>, 'a) => unit = "toBeGreaterThanOrEqual"
@send external toBeLessThan: (expect<'a>, 'a) => unit = "toBeLessThan"
@send external toBeLessThanOrEqual: (expect<'a>, 'a) => unit = "toBeLessThanOrEqual"
@send external toBeCloseTo: (expect<float>, float, ~digits: int=?) => unit = "toBeCloseTo"
@send external toContain: (expect<array<'a>>, 'a) => unit = "toContain"
@send external toContainString: (expect<string>, string) => unit = "toContain"
@send external toHaveLength: (expect<array<'a>>, int) => unit = "toHaveLength"
@send external toMatch: (expect<string>, string) => unit = "toMatch"
@send external toThrow: expect<unit => 'a> => unit = "toThrow"

// .not modifier
type notExpect<'a>
@get external not_: expect<'a> => notExpect<'a> = "not"
@send external notToBe: (notExpect<'a>, 'a) => unit = "toBe"
@send external notToEqual: (notExpect<'a>, 'a) => unit = "toEqual"
@send external notToBeDefined: notExpect<'a> => unit = "toBeDefined"
@send external notToBeUndefined: notExpect<'a> => unit = "toBeUndefined"
@send external notToContain: (notExpect<array<'a>>, 'a) => unit = "toContain"
