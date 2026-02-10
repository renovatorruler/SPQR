# ReScript Type Manifesto — LLM Reference

> Human-readable version with full explanations: `RESCRIPT_MANIFESTO.MD`
> This file is optimized for LLM code generation. Examples over prose.

---

## All rules at a glance

```
0. SHIFT LEFT INTO TYPES — encode assumptions in the type system, not runtime checks
1. DOMAIN-TYPED PRIMITIVES — all domain values must be @unboxed types (or opaque modules for validation)
2. MAKE IMPOSSIBLE STATES IMPOSSIBLE — variants over booleans and option combinations
3. NEVER USE DEFAULT VALUES — explicit option or loading variants, no magic zeros
4. SHARED TYPES ACROSS BOUNDARIES — frontend and backend share the same type definitions
5. PARSE, DON'T VALIDATE — transform to types at boundary, work typed internally
6. EXHAUSTIVE MATCHING — no wildcards on domain variant types
7. ERRORS AS VALUES — result types, not exceptions
8. TOTAL FUNCTIONS — return a value for all inputs, or make bad inputs unrepresentable
9. TYPES FIRST — design types before implementation
10. CONSTRAIN MUTATION — immutable by default, contained mutation when needed
```

### Escape hatches

```
FORBIDDEN — Obj.magic (always)
FORBIDDEN — %raw / %%raw (always, unconditionally, no exceptions)
ALLOWED AT BOUNDARIES — %identity (documented serialization points only)
```

### Cross-cutting rule: Use stdlib utility functions

**Always use `Option.*` and `Result.*` utility functions instead of hand-rolling switch expressions.**

```rescript
// ❌ BAD: Hand-rolled Option.map
switch maybeValue {
| Some(x) => Some(f(x))
| None => None
}

// ✅ GOOD: Use the stdlib
maybeValue->Option.map(f)

// ❌ BAD: Hand-rolled Result.mapError
switch result {
| Ok(v) => Ok(v)
| Error(e) => Error(transform(e))
}

// ✅ GOOD: Use the stdlib
result->Result.mapError(transform)
```

Common stdlib functions you MUST use instead of hand-rolling:

```
Option.map          — Some(x) => Some(f(x)), None => None
Option.flatMap      — Some(x) => g(x), None => None  (where g returns option)
Option.getOr        — Some(x) => x, None => default
Option.isSome       — Some(_) => true, None => false
Option.isNone       — Some(_) => false, None => true
Option.forEach      — Some(x) => sideEffect(x), None => ()
Result.map          — Ok(x) => Ok(f(x)), Error(e) => Error(e)
Result.flatMap      — Ok(x) => g(x), Error(e) => Error(e)
Result.mapError     — Ok(x) => Ok(x), Error(e) => Error(f(e))
Result.getOr        — Ok(x) => x, Error(_) => default
Result.isOk         — Ok(_) => true, Error(_) => false
Result.isError      — Ok(_) => false, Error(_) => true
```

Only use `switch` on Option/Result when you need to:
- Match on specific variant payloads (e.g., `| Error(NotFound) => ... | Error(Unauthorized) => ...`)
- Execute complex branching logic that doesn't map to a single stdlib call

### Cross-cutting rule: No for-loops — use functional iteration

**Never use `for` loops. Use `Array.map`, `Array.filter`, `Array.reduce`, `Array.forEach`, and other functional iteration methods.**

```rescript
// ❌ BAD: Imperative for-loop
let doubled = []
for i in 0 to items->Array.length - 1 {
  doubled->Array.push(items[i]->Option.getOr(0) * 2)
}

// ✅ GOOD: Functional — Array.map
let doubled = items->Array.map(x => x * 2)

// ❌ BAD: Imperative accumulation
let mut total = 0
for i in 0 to items->Array.length - 1 {
  total = total + items[i]->Option.getOr(0)
}

// ✅ GOOD: Functional — Array.reduce
let total = items->Array.reduce(0, (acc, x) => acc + x)

// ❌ BAD: Imperative filter
let results = []
for i in 0 to items->Array.length - 1 {
  if items[i]->Option.getOr(0) > 10 {
    results->Array.push(items[i]->Option.getOr(0))
  }
}

// ✅ GOOD: Functional — Array.filter
let results = items->Array.filter(x => x > 10)
```

**One exception**: Sequential async processing where each iteration must complete before the next starts. This is the ONLY acceptable use of `for`:

```rescript
// ✅ OK: Sequential async — explicit justification required
let processSequentially = async (items: array<item>) => {
  // Justification: each API call must complete before the next (rate limiting)
  for i in 0 to items->Array.length - 1 {
    switch items[i] {
    | Some(item) => await processItem(item)
    | None => ()
    }
  }
}
```

### Cross-cutting rule: switch over if-then chains

**Use `switch` expressions instead of `if/else if/else` chains. Pattern matching is more expressive and the compiler can check exhaustiveness.**

```rescript
// ❌ BAD: if-then chain — no exhaustiveness checking
let getDiscount = (tier: memberTier) => {
  if tier == Gold {
    0.2
  } else if tier == Silver {
    0.1
  } else if tier == Bronze {
    0.05
  } else {
    0.0
  }
}

// ✅ GOOD: switch — exhaustive, compiler warns if case added
let getDiscount = (tier: memberTier) => {
  switch tier {
  | Gold => 0.2
  | Silver => 0.1
  | Bronze => 0.05
  }
}

// ❌ BAD: Nested if-else for multiple conditions
let categorize = (score: int) => {
  if score >= 90 {
    "A"
  } else if score >= 80 {
    "B"
  } else if score >= 70 {
    "C"
  } else {
    "F"
  }
}

// ✅ GOOD: switch with guards
let categorize = (score: int) => {
  switch score {
  | s if s >= 90 => "A"
  | s if s >= 80 => "B"
  | s if s >= 70 => "C"
  | _ => "F"
  }
}
```

**Acceptable `if` usage**: Simple single-condition boolean checks with no chaining:

```rescript
// ✅ OK: Single boolean condition, no chain
if isEmpty {
  showEmptyState()
}

// ✅ OK: Simple validation guard in a make function
if s->String.length == 0 {
  Error(#Empty)
} else {
  s->Email->Ok
}
```

### Quick rejection criteria — immediately request changes if you see:

```
1. Obj.magic anywhere
2. %raw or %%raw anywhere
3. Multiple related booleans in a record
4. Strings used for enums/status values
5. -1, "", [] used as sentinel values
6. Wildcard patterns on domain variant types
7. getExn or getUnsafe without justification
8. Duplicate type definitions across frontend/backend
9. Hand-rolled switch on Option/Result that duplicates a stdlib function
10. for-loops without explicit justification
11. if/else if chains — use switch instead
```

---

## Principle 0: Shift left into types

**Encode assumptions in the type system. What the compiler checks, you don't need to test or debug.**

```rescript
// ❌ BAD: Runtime validation — can be forgotten, inconsistent, runs every call
let processOrder = (orderId: string, quantity: int, userId: string) => {
  if orderId->String.length == 0 {
    raise(InvalidArgument("orderId cannot be empty"))
  }
  if quantity <= 0 {
    raise(InvalidArgument("quantity must be positive"))
  }
  // ...
}

// ✅ GOOD: Type-encoded assumptions — compiler enforces, zero runtime cost
module OrderId: {
  type t
  let make: string => option<t>
  let toString: t => string
} = {
  type t = string
  let make = s =>
    Regex.test(%re("/^ORD-[A-Z0-9]{5}$/"), s) ? Some(s) : None
  let toString = t => t
}

module PositiveInt: {
  type t
  let make: int => option<t>
  let toInt: t => int
} = {
  type t = int
  let make = n => n > 0 ? Some(n) : None
  let toInt = t => t
}

@unboxed type userId = UserId(string)

// Function signature ENFORCES assumptions — no validation needed inside
let processOrder = (orderId: OrderId.t, quantity: PositiveInt.t, userId: userId) => {
  // just business logic
}

// Caller must provide valid types — no way around it
switch (OrderId.make(rawOrderId), PositiveInt.make(rawQuantity)) {
| (Some(oid), Some(qty)) => processOrder(oid, qty, UserId(rawUserId))
| (None, _) => Error(#InvalidOrderId)
| (_, None) => Error(#InvalidQuantity)
}
```

### Complete before/after: Order shipping

```rescript
// ❌ BAD: Runtime validation everywhere, 10+ test cases needed
type order = {
  id: string,
  items: array<orderItem>,
  status: string, // "pending" | "paid" | "shipped" | "delivered" | "cancelled"
  discount: float, // 0.0 to 1.0
  shippingAddress: option<string>,
}

let shipOrder = (order: order): result<order, string> => {
  if order.id->String.length == 0 {
    Error("Order ID cannot be empty")
  } else if order.items->Array.length == 0 {
    Error("Order must have at least one item")
  } else if order.status != "paid" {
    Error("Can only ship paid orders")
  } else {
    switch order.shippingAddress {
    | None => Error("Shipping address required")
    | Some(addr) if addr->String.length == 0 => Error("Shipping address cannot be empty")
    | Some(_) =>
      if order.discount < 0.0 || order.discount > 1.0 {
        Error("Invalid discount")
      } else {
        Ok({...order, status: "shipped"})
      }
    }
  }
}

// ✅ GOOD: Types make invalid states unrepresentable — just the happy path needed
@unboxed type orderId = OrderId(string)
@unboxed type shippingAddress = ShippingAddress(string)
type nonEmptyArray<'a> = NonEmptyArray({first: 'a, rest: array<'a>})

module Percentage: {
  type t
  let make: float => option<t>
  let toFloat: t => float
} = {
  type t = float
  let make = f => (f >= 0.0 && f <= 1.0) ? Some(f) : None
  let toFloat = t => t
}

// State machine: each state is its own type
type paidOrder = {
  id: orderId,
  items: nonEmptyArray<orderItem>,
  discount: Percentage.t,
  paidAt: timestamp,
  shippingAddress: shippingAddress,
}

type shippedOrder = {
  id: orderId,
  items: nonEmptyArray<orderItem>,
  discount: Percentage.t,
  paidAt: timestamp,
  shippingAddress: shippingAddress,
  shippedAt: timestamp,
  trackingNumber: trackingNumber,
}

// ONLY accepts paidOrder — impossible to call with wrong state
let shipOrder = (order: paidOrder, trackingNumber: trackingNumber): shippedOrder => {
  {
    id: order.id,
    items: order.items,
    discount: order.discount,
    paidAt: order.paidAt,
    shippingAddress: order.shippingAddress,
    shippedAt: Timestamp.now(),
    trackingNumber,
  }
}
```

---

## Principle 1: Domain-typed primitives

**Never use raw `string`, `int`, `float`, `bool` directly. All domain values must be unboxed types.**

### Default: `@unboxed` single-variant types

`@unboxed` is the standard. It gives you nominal type safety at zero runtime cost — the wrapper is erased at compile time, so you get a plain string/int/float/bool in JavaScript output.

```rescript
// ❌ BAD: Raw primitives — args can be silently swapped
let authenticate = (user: string, pass: string) => { /* ... */ }
authenticate(password, username) // compiles! catastrophic bug

// ✅ GOOD: @unboxed types — compiler catches swaps, zero runtime cost
@unboxed type username = Username(string)
@unboxed type password = Password(string)
@unboxed type email = Email(string)
@unboxed type userId = UserId(int)
@unboxed type hourlyRate = HourlyRate(float)
@unboxed type orderId = OrderId(string)

let authenticate = (user: username, pass: password) => { /* ... */ }
authenticate(pass, user) // ❌ TYPE ERROR
```

### Destructuring: right before use, not inline

Do NOT destructure in function parameters. Destructure with a `let` binding right before you need the raw value.

```rescript
// ❌ BAD: Inline destructuring in function parameter
let displayUser = (Username(name)) => `User: ${name}`

// ✅ GOOD: Destructure right before use
let displayUser = (user: username) => {
  let Username(name) = user
  `User: ${name}`
}

// ✅ GOOD: Multiple destructurings right before use
let formatOrder = (id: orderId, user: username) => {
  let OrderId(oid) = id
  let Username(uname) = user
  `Order ${oid} for ${uname}`
}

// ✅ GOOD: Destructure in the scope where you need the raw value
let renderDeityCard = (deity: deity) => {
  let DeityId(deityIdStr) = deity.id
  let UserName(ownerName) = deity.ownerName
  <Card key=deityIdStr>
    <Text>{React.string(ownerName)}</Text>
  </Card>
}

// ✅ GOOD: Destructure colors right before styling
let makeStyles = () => {
  let HexColor(primary) = TempleColors.lampFlame
  let HexColor(background) = TempleColors.backgroundPrimary
  {
    container: Style.make(~backgroundColor=background, ()),
    title: Style.make(~color=primary, ()),
  }
}
```

### When to use modules instead: validation or hidden internals

Upgrade to a module with opaque type when you need to enforce invariants at construction time or hide the internal value.

```rescript
// ✅ GOOD: Opaque module — can't construct invalid values
module Email: {
  type t
  let make: string => result<t, [#InvalidFormat | #Empty]>
  let toString: t => string
} = {
  @unboxed type t = Email(string)
  let make = s => {
    if s->String.length == 0 {
      Error(#Empty)
    } else if !(s->String.includes("@")) {
      Error(#InvalidFormat)
    } else {
      s->Email->Ok
    }
  }
  let toString = (email: t) => {
    let Email(s) = email
    s
  }
}

// ✅ GOOD: Opaque module — intentionally hides value (no toString)
module Password: {
  type t
  let make: string => result<t, [#TooShort | #NoNumber]>
  let verify: (t, string) => bool
  // Note: NO toString — cannot extract password
} = {
  @unboxed type t = Password(string)
  let make = s => {
    if s->String.length < 8 {
      Error(#TooShort)
    } else if !(s->String.match(%re("/[0-9]/"))->Option.isSome) {
      Error(#NoNumber)
    } else {
      s->Password->Ok
    }
  }
  let verify = (password: t, candidate) => {
    let Password(p) = password
    p == candidate
  }
}
```

### Decision guide

```rescript
// @unboxed type (default for almost everything)
@unboxed type firstname = Firstname(string)
@unboxed type lastname = Lastname(string)
@unboxed type userId = UserId(int)
@unboxed type orderId = OrderId(string)
@unboxed type quantity = Quantity(int)
@unboxed type latitude = Latitude(float)
@unboxed type longitude = Longitude(float)
@unboxed type hexColor = HexColor(string)
@unboxed type timestamp = Timestamp(float)
@unboxed type isVerified = IsVerified(bool)
@unboxed type isActive = IsActive(bool)

// Module with opaque type (only when you need these):
// - Validation at construction (Email, URL)
// - Hidden internals (Password — no extraction)
// - Restricted operations (Money — can't add different currencies)
```

---

## Principle 2: Make impossible states impossible

**Use variant types to model only the states that can actually exist.**

```rescript
// ❌ BAD: 2 × 2 × 2 × 2 = 16 combinations, only 4-5 are valid
type apiRequest = {
  isLoading: bool,
  data: option<userData>,
  error: option<string>,
  hasTimedOut: bool,
}
// This compiles but is nonsense:
let nonsense = { isLoading: true, data: Some(userData), error: Some("failed"), hasTimedOut: true }

// ✅ GOOD: Only valid states representable
type apiRequest<'data, 'error> =
  | Idle
  | Loading
  | Success('data)
  | Failed('error)
  | TimedOut

let render = (state: apiRequest<userData, string>) => {
  switch state {
  | Idle => <Button onClick=fetch>"Load Data"</Button>
  | Loading => <Spinner />
  | Success(user) => <UserProfile user />
  | Failed(message) => <ErrorDisplay message />
  | TimedOut => <TimeoutMessage onRetry=fetch />
  }
}
```

### Form states

```rescript
// ❌ BAD: Can be submitting AND submitted simultaneously
type form = {
  isSubmitting: bool,
  isSubmitted: bool,
  isDirty: bool,
  values: formValues,
  errors: option<formErrors>,
}

// ✅ GOOD: Clear state machine
type formState<'values, 'errors, 'result> =
  | Editing({values: 'values, errors: option<'errors>})
  | Submitting({values: 'values})
  | Submitted({result: 'result})
  | SubmissionFailed({values: 'values, reason: 'errors})
```

### User session

```rescript
// ❌ BAD: isLoggedIn: true but userId: None? Nonsense.
type user = {
  isLoggedIn: bool,
  userId: option<userId>,
  email: option<email>,
  role: option<role>,
}

// ✅ GOOD: States are self-consistent
type session =
  | Anonymous
  | Authenticated({userId: userId, email: email, role: role})

let canAccessAdminPanel = (session: session) => {
  switch session {
  | Anonymous => false
  | Authenticated({role: Admin | SuperAdmin}) => true
  | Authenticated({role: Member}) => false
  }
}
```

### Payment processing

```rescript
// ❌ BAD: Boolean soup
type payment = {
  isPending: bool,
  isComplete: bool,
  isFailed: bool,
  failureReason: option<string>,
  transactionId: option<string>,
}

// ✅ GOOD: Each state carries exactly the data it needs
type paymentFailure =
  | InsufficientFunds
  | CardDeclined
  | NetworkError
  | FraudSuspected

type paymentStatus =
  | Pending({initiatedAt: timestamp})
  | Processing({processorRef: processorRef})
  | Completed({transactionId: transactionId, completedAt: timestamp})
  | Failed({reason: paymentFailure, failedAt: timestamp})
  | Refunded({originalTxn: transactionId, refundTxn: transactionId, refundedAt: timestamp})
```

### The boolean smell test

```rescript
// 🚨 Two or more related booleans? You want a variant.
type request = { isLoading: bool, isError: bool }            // ❌
type user = { isVerified: bool, verifiedAt: option<timestamp> } // ❌
type result = { data: option<data>, error: option<error> }    // ❌
// All of these should be variants.
```

---

## Principle 3: Never use default values

**Represent absence explicitly. Never conflate "unknown" with a valid value.**

```rescript
// ❌ BAD: Default values hide missing data
type employee = {
  name: string,
  hourlyRate: float,   // Default 0.0 while loading? But 0 is valid!
  departmentId: int,   // Default -1? Magic number!
  startDate: string,   // Default ""? Unparseable!
}
// Silent bug: if hourlyRate not loaded, calculates $0
let calculatePay = (emp, hours) => emp.hourlyRate *. hours

// ✅ GOOD: Explicit about what we know
type employee = {
  name: name,
  hourlyRate: option<hourlyRate>,
  departmentId: departmentId,
  startDate: date,
}

let calculatePay = (emp: employee, hours: float) => {
  emp.hourlyRate->Option.map(hourlyRate => {
    let HourlyRate(rate) = hourlyRate
    rate *. hours
  })
}

// ✅ BETTER: Model loading states — if Loaded, all fields present
type employeeState =
  | Loading
  | Loaded(employee)
  | FailedToLoad(fetchError)

type employee = {
  name: name,
  hourlyRate: hourlyRate, // not optional! if Loaded, we have it
  departmentId: departmentId,
  startDate: date,
}
```

### Eliminating magic values

```rescript
// ❌ BAD: Magic values
let notFound = -1
let noUser = 0
let emptyDate = ""

// ✅ GOOD: Types prevent misuse
type searchResult<'a> =
  | Found({index: int, value: 'a})
  | NotFound

switch findIndex(users, targetUser) {
| Found({index, value}) => Console.log(`Found at ${index->Int.toString}`)
| NotFound => Console.log("Not in list")
}
```

### Common violations

```rescript
// ❌ Empty array as "no data" — empty or not loaded?
let users: array<user> = []
// ✅
type usersState = NotLoaded | Loaded(array<user>)

// ❌ Empty string as "not entered" — not searched or cleared?
let searchQuery = ""
// ✅
type searchState = NoSearch | Searching(query) | Results({query: query, results: array<result>})

// ❌ Zero as "not set" — first item or nothing selected?
let selectedIndex = 0
// ✅
let selectedIndex: option<int> = None
```

---

## Principle 4: Shared types across boundaries

**Frontend and backend share the same type definitions. No duplicated assumptions.**

```rescript
// ❌ BAD: Backend and frontend define types independently — they WILL drift
// backend/Types.res
type user = { id: int, name: string, role: string }
// frontend/Types.res
type user = { id: int, userName: string, role: string } // Wrong field name!

// ✅ GOOD: Single source of truth in shared package
// shared/src/Domain.res — both backend and frontend depend on this
@unboxed type userId = UserId(int)
@unboxed type email = Email(string)
@unboxed type timestamp = Timestamp(float)

type role =
  | Member
  | Admin
  | SuperAdmin

type accountStatus =
  | Active
  | Suspended({reason: string, until: option<timestamp>})
  | Deleted({deletedAt: timestamp})

type user = {
  id: userId,
  email: email,
  role: role,
  status: accountStatus,
  createdAt: timestamp,
}
```

### Shared API contracts

```rescript
// shared/src/Api.res
type createUserRequest = {
  email: email,
  password: string,
  role: role,
}

type apiError =
  | ValidationError({fields: array<(string, string)>})
  | NotFound({resource: string, id: string})
  | Unauthorized
  | Forbidden
  | ServerError({message: string})

type apiResult<'a> = result<'a, apiError>

// ❌ BAD: Stringly-typed API responses
type apiResponse = {
  status: string,    // "success" | "error" — not type-safe!
  data: JSON.t,      // untyped blob
}

// ✅ GOOD: Fully typed shared response
type apiResponse<'data, 'error> =
  | Success({data: 'data})
  | Failed({error: 'error})
```

### What to share vs. keep separate

```
SHARE: domain entities, domain primitives, API request/response types,
       validation error types, status enums/variants, business logic result types

KEEP SEPARATE: database row types, ORM-specific types, internal backend services,
               logging types, UI component props, React hook return types
```

---

## Principle 5: Parse, don't validate

**Transform unstructured data into typed data once, at the boundary.**

```rescript
// ❌ BAD: Validate repeatedly — still have untyped data after validation
let processUser = (json: JSON.t) => {
  if !isValidEmail(json["email"]) {
    Error("Invalid email")
  } else {
    let email = json["email"] // still a string!
    sendWelcomeEmail(email)   // is this validated? who knows!
  }
}

// ✅ GOOD: Parse at boundary, work with types internally
let parseUser = (json: JSON.t): result<user, parseError> => {
  switch (json->JSON.Decode.object) {
  | None => Error(InvalidFormat("Expected object"))
  | Some(obj) =>
    switch (
      obj->Dict.get("id")->Option.flatMap(JSON.Decode.int),
      obj->Dict.get("email")->Option.flatMap(JSON.Decode.string),
      obj->Dict.get("role")->Option.flatMap(parseRole),
    ) {
    | (Some(id), Some(emailStr), Some(role)) =>
      switch Email.make(emailStr) {
      | Ok(email) => {id: id->UserId, email, role}->Ok
      | Error(e) => Error(InvalidField("email", e))
      }
    | _ => Error(MissingFields)
    }
  }
}

// Internal functions ONLY accept typed values — no validation needed
let sendWelcomeEmail = (email: Email.t) => {
  // email is guaranteed valid — it was parsed!
}

let processUser = (json: JSON.t) => {
  switch parseUser(json) {
  | Ok(user) => sendWelcomeEmail(user.email) // fully typed, no uncertainty
  | Error(e) => handleParseError(e)
  }
}
```

---

## Principle 6: Exhaustive matching, no wildcards

**Always match every variant explicitly. Never use catch-all patterns for domain types.**

```rescript
type paymentStatus = Pending | Completed | Failed | Refunded

// ❌ BAD: Wildcard hides future bugs
let statusMessage = (status: paymentStatus) => {
  switch status {
  | Completed => "Payment successful"
  | Failed => "Payment failed"
  | _ => "Processing..." // catches Pending AND Refunded (wrong!)
  }
}
// When someone adds | Disputed — it silently falls into "Processing..."

// ✅ GOOD: Exhaustive matching — compiler forces you to handle new cases
let statusMessage = (status: paymentStatus) => {
  switch status {
  | Pending => "Processing..."
  | Completed => "Payment successful"
  | Failed => "Payment failed"
  | Refunded => "Refund issued"
  }
}
// When Disputed is added: compile error! You MUST handle it.
```

### When wildcards are OK

```rescript
// ✅ OK: External/infinite types (int has infinite values)
let parseHttpStatus = (code: int) => {
  switch code {
  | 200 => Ok(Success)
  | 201 => Ok(Created)
  | 400 => Error(BadRequest)
  | 404 => Error(NotFound)
  | 500 => Error(ServerError)
  | _ => Error(Unknown(code)) // OK: int is infinite
  }
}

// ❌ NOT OK: Your own variant types — always match exhaustively
```

---

## Principle 7: Errors as values

**Use `result` types for operations that can fail. Never throw exceptions for expected failures.**

```rescript
// ❌ BAD: Type says int but might throw — type signature lies
let divide = (a: int, b: int): int => {
  if b == 0 { raise(Division_by_zero) } else { a / b }
}

// ✅ GOOD: Type signature tells you it can fail
let divide = (a: int, b: int): result<int, [#DivisionByZero]> => {
  b == 0 ? Error(#DivisionByZero) : Ok(a / b)
}

// Caller MUST handle the error
switch divide(10, x) {
| Ok(result) => Console.log(`Result: ${result->Int.toString}`)
| Error(#DivisionByZero) => Console.log("Cannot divide by zero")
}
```

### Result chaining

```rescript
let processOrder = (orderId: string): result<receipt, orderError> => {
  orderId
  ->parseOrderId
  ->Result.flatMap(fetchOrder)
  ->Result.flatMap(validateInventory)
  ->Result.flatMap(processPayment)
  ->Result.flatMap(generateReceipt)
}
```

### Typed error variants

```rescript
// ✅ GOOD: Rich, specific error types — not just strings
type orderError =
  | InvalidOrderId({given: string})
  | OrderNotFound({id: orderId})
  | InsufficientInventory({item: itemId, requested: int, available: int})
  | PaymentFailed({reason: paymentFailure})
  | SystemError({message: string})

let handleError = (error: orderError) => {
  switch error {
  | InvalidOrderId({given}) => `"${given}" is not a valid order ID`
  | OrderNotFound({id}) => `Order ${OrderId.toString(id)} not found`
  | InsufficientInventory({item, requested, available}) =>
    `Only ${available->Int.toString} of ${ItemId.toString(item)} available`
  | PaymentFailed({reason}) => formatPaymentError(reason)
  | SystemError({message}) => `System error: ${message}`
  }
}
```

### When to use what

```rescript
// Expected, recoverable failure → result<'a, 'e>
// Value might not exist → option<'a>
// Programmer error / bug → assert or panic (should never happen in prod)
// Truly exceptional (out of memory) → exception (can't reasonably handle)
```

---

## Principle 8: Total functions

**Every function should return a value for every possible input.**

```rescript
// ❌ BAD: Partial function — explodes on empty array
let head = (arr: array<'a>): 'a => arr[0]

// ✅ GOOD: Total function — returns option
let head = (arr: array<'a>): option<'a> => arr[0]

switch head(someArray) {
| Some(first) => process(first)
| None => handleEmpty()
}

// ✅ BETTER: Make bad inputs unrepresentable
type nonEmptyArray<'a> = NonEmptyArray({first: 'a, rest: array<'a>})

let average = (numbers: nonEmptyArray<float>): float => {
  let NonEmptyArray({first, rest}) = numbers
  let sum = first +. rest->Array.reduce((a, b) => a +. b, 0.0)
  sum /. (1 + rest->Array.length)->Int.toFloat
  // Always returns float — can't be called with empty!
}
```

---

## Principle 9: Types first (type-driven design)

**Design your types before writing implementation.**

```rescript
// STEP 1: Model the domain with types (no implementation yet)
type player = { id: playerId, name: playerName, score: score }

type gameState =
  | WaitingForPlayers({players: array<player>, minPlayers: int})
  | InProgress({players: nonEmptyArray<player>, currentTurn: playerId, round: int})
  | Finished({winner: player, finalScores: array<(player, score)>})

type gameCommand =
  | JoinGame(player)
  | LeaveGame(playerId)
  | StartGame
  | TakeTurn(action)

// STEP 2: Define function signatures (still no implementation)
let handleCommand: (gameState, gameCommand) => result<(gameState, array<gameEvent>), gameError>

// STEP 3: Implement — the types guide you
let handleCommand = (state, command) => {
  switch (state, command) {
  | (WaitingForPlayers({players}), JoinGame(player)) =>
    Ok((WaitingForPlayers({players: players->Array.concat([player]), minPlayers: 2}), [PlayerJoined(player)]))
  | (WaitingForPlayers({players}), StartGame) if players->Array.length < 2 =>
    Error(NotEnoughPlayers)
  // compiler tells you what cases you missed
  }
}
```

---

## Principle 10: Constrain mutation

**Prefer immutable data. When mutation is necessary, contain and isolate it.**

```rescript
// ❌ BAD: Unrestricted mutation — anywhere in codebase can mutate
let users = ref([])
let addUser = (user) => {
  users := users.contents->Array.concat([user])
}

// ✅ GOOD: Pure function — old state in, new state out
type state = { users: array<user>, posts: array<post> }

let addUser = (state: state, user: user): state => {
  { ...state, users: state.users->Array.concat([user]) }
}

// ✅ OK: Mutation contained in local scope during construction
let buildLookupTable = (users: array<user>): Dict.t<user> => {
  let table = Dict.make()
  users->Array.forEach(user => {
    table->Dict.set(UserId.toString(user.id), user)
  })
  table // returned and never mutated again
}
```

---

## Escape hatches: FORBIDDEN

### Obj.magic — FORBIDDEN always

```rescript
// ❌ FORBIDDEN
let x: string = Obj.magic(42)
let message = switch JsExn.message(Obj.magic(exn)) { | Some(msg) => msg | None => "Unknown" }
let json = someValue->Obj.magic

// ✅ GOOD: Proper exception handling
let extractErrorMessage = (exn: exn): string => {
  switch exn {
  | JsExn.JsError(jsExn) =>
    jsExn->JsExn.message->Option.getOr("Unknown error")
  | _ => "Unknown error"
  }
}

// ✅ GOOD: Typed error variants
type appError =
  | NetworkError({message: string, status: option<int>})
  | ParseError({message: string})
  | UnknownError({message: string})
```

### %raw / %%raw — UNCONDITIONALLY FORBIDDEN

```rescript
// ❌ FORBIDDEN — no exceptions, not even for tests or generated code
let add: (int, int) => int = %raw(`function(a, b) { return a + b; }`)
%%raw(`import something from 'some-library';`)
let getElement: string => 'a = %raw(`function(id) { return document.getElementById(id); }`)

// ✅ GOOD: Proper bindings
@module("./myModule")
external myFunction: (int, int) => int = "add"

@val @scope("document")
external getElementById: string => Nullable.t<Dom.element> = "getElementById"

@val @scope("window")
external addEventListener: (string, 'event => unit) => unit = "addEventListener"

// ✅ GOOD: Playwright browser context — use typed bindings, not %raw
@send external evaluateWithArg: (Page.t, string => bool, string) => Promise.t<bool> = "evaluate"
```

### %identity — allowed at documented serialization boundaries only

```rescript
// ✅ ACCEPTABLE: React Navigation params (documented boundary)
external toJs: t => {..} = "%identity"

// ✅ ACCEPTABLE: Style creation (zero-cost wrapper)
external make: {..} => t = "%identity"

// ✅ ACCEPTABLE: Image source union types
external sourceFromRequire: int => source = "%identity"

// ❌ NOT ACCEPTABLE: Casting unrelated types
external stringToInt: string => int = "%identity"
external rawEmailToEmail: string => Email.t = "%identity"
```

---

## ppx_spice: Type-safe JSON serialization

### Variant types with custom JSON values

```rescript
@spice
type skinTone =
  | @spice.as("vermillion") Vermillion
  | @spice.as("golden") Golden
  | @spice.as("moonstone") Moonstone

let encoded = skinTone_encode(Golden) // => "golden"
let decoded = skinTone_decode(JSON.Encode.string("golden")) // => Ok(Golden)
```

### Record types

```rescript
@spice
type user = {
  id: string,
  name: string,
  email: string,
  age: int,
  isActive: bool,
}

let encoded = user_encode({ id: "1", name: "Alice", email: "a@b.com", age: 30, isActive: true })
let decoded = user_decode(jsonValue) // => result<user, Spice.decodeError>
```

### Optional fields

```rescript
@spice
type profile = {
  name: string,
  bio: option<string>,      // encoded as null when None
  avatarUrl: option<string>,
}
```

### Field renaming

```rescript
@spice
type apiResponse = {
  @spice.key("type") responseType: string,
  @spice.key("created_at") createdAt: string,
  @spice.key("user_id") userId: string,
}
// JSON: {"type": "success", "created_at": "2024-01-01", "user_id": "123"}
```

### Wire/Domain pattern

```rescript
// Wire types: JSON-compatible, used at API boundary
module Wire = {
  @spice
  type user = { id: string, email: string, role: string }
}

// Domain types: Type-safe, used in application logic
module Domain = {
  @unboxed type userId = UserId(string)
  type role = Admin | Member | Guest
  type user = { id: userId, email: Email.t, role: role }
}

// Conversion at boundary
let userToDomain = (wire: Wire.user): option<Domain.user> => {
  switch (Email.make(wire.email), parseRole(wire.role)) {
  | (Some(email), Some(role)) =>
    Some({ id: Domain.UserId(wire.id), email, role })
  | _ => None
  }
}
```

### Error handling

```rescript
let handleDecode = (json: JSON.t) => {
  switch myType_decode(json) {
  | Ok(value) => processValue(value)
  | Error(err) =>
    Console.error(`Decode failed at ${err.path}: ${err.message}`)
    handleError()
  }
}
```

---

## React Native bindings

### Core pattern

```rescript
// Module wrapping with @module and @react.component
module View = {
  @module("react-native") @react.component
  external make: (
    ~style: Style.t=?,
    ~children: React.element=?,
    ~testID: string=?,
  ) => React.element = "View"
}

module Text = {
  @module("react-native") @react.component
  external make: (
    ~children: React.element=?,
    ~style: Style.t=?,
    ~numberOfLines: int=?,
    ~ellipsizeMode: [#head | #middle | #tail | #clip]=?,
  ) => React.element = "Text"
}

module Pressable = {
  type interactionState = {pressed: bool, hovered: bool}

  @module("react-native") @react.component
  external make: (
    ~onPress: unit => unit=?,
    ~onLongPress: unit => unit=?,
    ~disabled: bool=?,
    ~style: interactionState => Style.t=?,
    ~children: interactionState => React.element=?,
  ) => React.element = "Pressable"
}
```

### Type-safe enums with @as

```rescript
type keyboardType =
  | @as("default") Default
  | @as("email-address") EmailAddress
  | @as("numeric") Numeric
  | @as("phone-pad") PhonePad

type autoCapitalize =
  | @as("none") None
  | @as("sentences") Sentences
  | @as("words") Words
  | @as("characters") Characters

module TextInput = {
  @module("react-native") @react.component
  external make: (
    ~value: string=?,
    ~onChangeText: string => unit=?,
    ~placeholder: string=?,
    ~keyboardType: keyboardType=?,
    ~autoCapitalize: autoCapitalize=?,
    ~secureTextEntry: bool=?,
    ~style: Style.t=?,
  ) => React.element = "TextInput"
}
```

### Expo bindings

```rescript
module ExpoHaptics = {
  module ImpactFeedbackStyle = {
    type t =
      | @as("light") Light
      | @as("medium") Medium
      | @as("heavy") Heavy
  }

  @module("expo-haptics")
  external impactAsync: ImpactFeedbackStyle.t => Promise.t<unit> = "impactAsync"

  @module("expo-haptics")
  external selectionAsync: unit => Promise.t<unit> = "selectionAsync"
}

module ExpoImage = {
  type contentFit =
    | @as("cover") Cover
    | @as("contain") Contain
    | @as("fill") Fill
    | @as("none") None
    | @as("scale-down") ScaleDown

  @module("expo-image") @react.component
  external make: (
    ~source: string,
    ~style: Style.t=?,
    ~contentFit: contentFit=?,
    ~placeholder: string=?,
    ~transition: int=?,
  ) => React.element = "Image"
}
```

### Hook bindings with typed returns

```rescript
module Platform = {
  @module("react-native") @scope("Platform")
  external osString: string = "OS"

  type os = IOS | Android | Web | Unknown

  let os = (): os => {
    switch osString {
    | "ios" => IOS
    | "android" => Android
    | "web" => Web
    | _ => Unknown
    }
  }
}

module Appearance = {
  type colorScheme = Light | Dark

  @module("react-native")
  external useColorSchemeRaw: unit => Nullable.t<string> = "useColorScheme"

  let useColorScheme = (): colorScheme => {
    switch useColorSchemeRaw()->Nullable.toOption {
    | Some("dark") => Dark
    | _ => Light
    }
  }
}
```

### Subscription pattern

```rescript
module AppState = {
  type t = Active | Background | Inactive | Unknown
  type subscription

  @send external remove: subscription => unit = "remove"
  @module("react-native") @scope("AppState")
  external addEventListenerRaw: (string, string => unit) => subscription = "addEventListener"

  let onChange = (callback: t => unit): subscription => {
    addEventListenerRaw("change", rawState => {
      let state = switch rawState {
      | "active" => Active
      | "background" => Background
      | "inactive" => Inactive
      | _ => Unknown
      }
      callback(state)
    })
  }
}

// Usage with useEffect
React.useEffect0(() => {
  let subscription = AppState.onChange(state => {
    switch state {
    | AppState.Active => Console.log("App is active")
    | AppState.Background => Console.log("App is in background")
    | _ => ()
    }
  })
  Some(() => subscription->AppState.remove)
})
```

---

## React patterns

```rescript
// Component
@react.component
let make = (~name: string, ~onClick: unit => unit) => {
  <button onClick={_ => onClick()}>
    {React.string(name)}
  </button>
}

// State
let (count, setCount) = React.useState(() => 0)
setCount(prev => prev + 1)

// Effect with cleanup
React.useEffect0(() => {
  let subscription = subscribe()
  Some(() => unsubscribe(subscription))
})

// Memo
let memoizedValue = React.useMemo1(() => expensiveComputation(input), [input])
```

---

## Common operations quick reference

```rescript
// Array
arr->Array.map(x => x * 2)
arr->Array.filter(x => x > 0)
arr->Array.find(x => x == target)             // option<'a>
arr->Array.reduce(0, (acc, x) => acc + x)
arr->Array.concat([4, 5])
arr->Array.flatMap(x => [x, x * 2])
arr[0]                                         // option<'a> — safe!

// String
s->String.length
s->String.includes("world")
s->String.split(" ")
s->String.slice(~start=0, ~end=5)
`Hello, ${name}!`

// Option — prefer stdlib, switch only for specific variant matching
some->Option.getOr(0)
some->Option.map(x => x * 2)
some->Option.flatMap(x => x > 0 ? Some(x) : None)
some->Option.forEach(use)

// Result — prefer stdlib, switch only for specific error matching
ok->Result.getOr(0)
ok->Result.map(x => x * 2)
ok->Result.flatMap(x => x > 0 ? Ok(x) : Error(InvalidInput("negative")))
result->Result.mapError(err => err.message)
// switch only when matching specific error variants:
switch result {
| Ok(value) => process(value)
| Error(NotFound) => handle()
| Error(InvalidInput(msg)) => report(msg)
}

// Dict
let dict = Dict.fromArray([("a", 1), ("b", 2)])
dict->Dict.get("a")                            // option<int>
dict->Dict.set("key", 42)

// Promise / async
let fetchUser = async (id: string) => {
  let response = await fetch(`/api/users/${id}`)
  let json = await response->Response.json
  json
}

// JSON
JSON.Encode.string("hello")
JSON.Decode.string(json)                        // option<string>
JSON.parseExn(jsonString)
JSON.stringify(json)

// Int / Float
42->Int.toString
Int.fromString("42")                            // option<int>
3.14->Float.toString
Float.fromString("3.14")                        // option<float>
```

---

## DO / DON'T summary

```
DO:
✅ @unboxed type userId = UserId(string)  — wrap primitives with @unboxed
✅ type state = Loading | Loaded(data)    — variants for states
✅ option<value> for absence              — explicit optionality
✅ result<ok, err> for fallible ops       — errors as values
✅ switch with all cases                  — exhaustive matching
✅ @spice for JSON                        — type-safe serialization
✅ @module for bindings                   — proper FFI
✅ Option.map / Result.map / etc.         — use stdlib utilities
✅ value->Constructor->Ok                 — pipe operators for construction
✅ Array.map / filter / reduce            — functional iteration
✅ switch over if/else if chains          — pattern matching for branching

DON'T:
❌ Obj.magic                              — forbidden always
❌ %raw or %%raw anywhere                 — unconditionally forbidden
❌ {isX: bool, isY: bool}                 — boolean soup
❌ "" or -1 for "not set"                 — magic values
❌ switch { | _ => }                      — wildcard on domain types
❌ getExn without justification           — unsafe unwrapping
❌ Duplicate types frontend/backend       — type drift
❌ Hand-rolled switch on Option/Result    — use stdlib functions instead
❌ for-loops                              — use Array.map/filter/reduce
❌ if/else if/else chains                 — use switch with pattern matching
```
