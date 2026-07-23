# Design Log — Challenges, Alternatives, Resolutions

> **Read this *before* the templates.**
>
> This document captures every real challenge we hit while building the
> Elite Generalist pipeline, the alternatives we considered, and the
> resolution we picked. The templates in `templates/` are the artifact
> *after* these decisions were made; this file is the artifact *of* the
> decisions.

The structure is the same in every section:

> **Challenge.** What we were trying to do, and what was hard about it.
> **Alternatives.** The real options on the table, with honest tradeoffs.
> **Resolution.** What we picked, and the reasons — not the marketing
> reasons, the *engineering* reasons.

If a resolution has a known limitation, we say so. Half the value of a
design log is knowing what you gave up.

---

## Part 0 — The overall workflow

### C0.1 — Mathematical purity vs. shipping a binary

**Challenge.** The philosophy says "mathematically optimized via Haskell /
Scala or similar FP abstractions". The reality is that every shipped
program does I/O, talks to a database, reads the clock. If the program is
pure, nothing happens. If it's impure, the discipline evaporates.

**Alternatives.**
- **α. Pure all the way down with `unsafePerformIO` at the top.** The
  classic Haskell 98 "imperative functional" pattern. Works, but the
  type system can't tell you which `IO` actions are pure wrappers and
  which actually do damage. You give up the very thing you're buying.
- **β. `mtl`-style monad transformer stack.** `ReaderT Config IO` for
  environment, `StateT AppState IO` for state. Elegant in a thesis,
  nightmarish in a 10,000-line codebase — every layer adds friction.
- **γ. Pure core, typed-effect boundary (ZIO / `RIO` / IO at the cliff).**
  The business logic is `AuditReport` → `AuditReport`. The boundary is
  one effect type (`ZIO[Clock, Throwable, AuditReport]`, or
  `RIO Clock AuditReport` in Haskell, or `IO AuditReport` for a script).
  The compiler enforces which is which.

**Resolution.** γ. Purity buys you referential transparency, which buys
you the property tests, which buy you the verification. The boundary
is *one type*, not a ladder of monad transformers. The Scala template
uses ZIO; the Haskell template uses plain `IO` because the demo is
small; in production we'd reach for `RIO` (the
[`rio`](https://hackage.haskell.org/package/rio) package).

**Known limitation.** ZIO's type signature is heavy. Junior engineers
read `ZIO[Clock, AuditError, AuditReport]` and panic. Mitigation:
Scaladoc on every effect, and a one-line `runAudit` wrapper that hides
the type.

---

### C0.2 — Property tests vs. example tests

**Challenge.** Property-based tests are harder to write, slower to run,
and generate noise (`+++ OK, passed 1000 tests; 235 shrank; 7 discarded`).
Example tests are easier to read. The philosophy says "verified by
construction".

**Alternatives.**
- **α. Pure example tests.** One test per branch, no shrinking, fast
  feedback. Misses the "weird input" cases that bite in production.
- **β. Pure property tests.** 1000 generated inputs per theorem, the
  test runner shrinks the counter-example. Forces you to state the
  *property*, which is itself clarifying.
- **γ. Hybrid.** Properties for the theorems (preserve total, never
  lose user, deterministic). Examples for the edge cases (empty list,
  single element, malformed input).

**Resolution.** γ. Every public function in `Audit.hs` and `Audit.scala`
has both. Properties live in `Spec.hs` / `AuditSpec.scala`. Examples are
inline in the source as `-- >>> prop_name input` doctest lines.

**Known limitation.** QuickCheck's `arbitrary` for `Money` only generates
*non-negative* values (we use `NonNegative`). That means the
`prop_auditPreservesTotal` property is only really testing the *credit*
branch deeply. The fix is to use the full range, but then the test
slows down because lots of generated values are zero. Filed as
`FUTURE-001` in the issue tracker.

---

### C0.3 — Keeping the dep set at 9

**Challenge.** The pitch says "9 transitive deps". FP culture is
"library for everything". Every convenience becomes a dep.

**Alternatives.**
- **α. Library for everything.** Add `optparse-applicative` for the
  CLI, `log4hs` for logging, `http-client` for the API. 40 deps in
  no time. SBOM is a phone book.
- **β. Stdlib only.** The audit pipeline can be written with
  `Data.List` and `Data.Aeson`. 0 deps. But you reinvent a lot of
  wheels (CSV parsing, JSON, property tests).
- **γ. Hand-pick 3 per stack.** Haskell: `aeson` (JSON), `text`
  (Unicode), `bytestring` (I/O), `cassava` (CSV), `QuickCheck`
  (properties). Scala: `zio` (effects), `zio-json` (JSON),
  `scalacheck` (properties). Literate C: 0.

**Resolution.** γ. Six Hackage packages, three Maven packages, zero
C packages. The "9 transitive" claim is true *today*; it would
require vigilance to keep it true tomorrow. The lockfile (`cabal.project.freeze`,
Maven `dependency-lock`) is the enforcement mechanism.

---

### C0.4 — Onboarding non-FP developers

**Challenge.** The team is mostly OOP/JS. Pure functions, monads,
opaque types are a foreign vocabulary.

**Alternatives.**
- **α. Don't bother, hire FP people.** Works in a vacuum. In reality,
  half the team is mid-career OOP engineers who don't want to learn
  Haskell.
- **β. Use Scala as the "gateway".** Scala 3 reads like OOP, has the
  types. `opaque type` is a single keyword; `enum` is familiar.
- **γ. Translate the pipeline to TypeScript with `fp-ts`.** Loses
  the type guarantees (TS is structural, not nominal) but keeps the
  shape.

**Resolution.** β + γ. Scala is the production language. TypeScript
is the prototype language, and a follow-up repo
(`elite-generalist-ts`) ports the same pipeline. Same shapes, two
languages.

---

### C0.5 — Scaling to a real codebase

**Challenge.** A 30-line pipeline is a toy. What about 10,000 lines?

**Alternatives.**
- **α. One mega-module.** Works until it doesn't.
- **β. Domain-driven modules.** `Ledger`, `User`, `Audit`, `Report`.
  Each module exposes 5-10 pure functions. Types are explicit at
  module boundaries. The compiler enforces the architecture.
- **γ. Tagless final / `mtl` everywhere.** Maximum type safety,
  minimum readability. Six months later, nobody can change anything.

**Resolution.** β. Each module is shaped like the demo: types, pure
functions, a single boundary effect. The pipeline becomes
`Audit.pipe(Report.from(Ledger.audit(Users.enrich(txs))))` — same
shape, just nested.

---

## Part 1 — The Haskell template

### C1.1 — `Money` newtype vs. plain `Integer`

**Challenge.** Integer arithmetic can silently mix `tx-0001` cents
with `tx-0001` calories. A wrong import and you've added 150000
calories to a tax return.

**Alternatives.**
- **α. Plain `Integer`.** 0 lines of code, total chaos.
- **β. Newtype `Money`.** One line of boilerplate, full type safety,
  zero runtime cost.
- **γ. Library.** `simple-money`, `coins`, `coda`. Solves a real
  problem, adds 2-3 deps, brings in `text` and `bytestring`
  transitively.

**Resolution.** β. The boilerplate is trivial. The runtime cost is
zero (newtype is erased). The dep count stays at 6.

```haskell
newtype Money = Money { cents :: Integer }
  deriving stock (Eq, Ord, Show, Generic)
  deriving newtype (ToJSON, FromJSON)
```

---

### C1.2 — `MiniMap` vs. `Data.Map.Strict`

**Challenge.** We need a small `Map UserId User` to do the join in
`enrichWith`. Do we add `containers` (already in GHC, so "free") or
roll a one-line solution?

**Alternatives.**
- **α. `Data.Map.Strict` from `containers`.** Bundled with GHC, no
  Hackage dep. O(log n) operations. Industry standard.
- **β. Hand-rolled `MiniMap`.** Pedagogical. Shows the join without
  hiding it behind a library. O(n) lookups (linear scan of an
  association list). Fine for n < 1000.
- **γ. `unordered-containers` (HashMap).** O(1) lookups, but adds
  a Hackage dep.

**Resolution.** β in the demo, α in production. The demo is for
teaching; production would import `Data.Map.Strict` and stop counting
it as a "real" dep because it's part of the GHC boot libraries.
The MiniMap stays as a teaching device.

**Known limitation.** For 100,000+ users the linear scan is
measurable. Document the threshold.

---

### C1.3 — QuickCheck `Arbitrary` for `Money` is half-coverage

**Challenge.** The `Arbitrary Money` instance uses `NonNegative`,
so it never generates a debit. The `prop_auditPreservesTotal`
property is therefore only deeply testing the credit branch.

**Alternatives.**
- **α. Full range.** `arbitrary = Money <$> choose (-1_000_000, 1_000_000)`.
  50% are zero, slows the test, but covers the debit path.
- **β. NonNegative (current).** Fast, misses the debit path.
- **γ. Two generators.** One for credit, one for debit. Then a
  `frequency` that mixes them.

**Resolution.** α. The 50% zeros are fine — we want zeros in the
test. The slowdown is negligible (1000 tests in <100ms). Filed
`FUTURE-001` to actually do this in the repo.

---

### C1.4 — `RecordWildCards` in `lookupUser`

**Challenge.** The helper `lookupUser` is written as

```haskell
lookupUser :: [UserSummary] -> Text -> Maybe UserSummary
lookupUser = foldr step Nothing
  where step s acc | userId' s == k = Just s | otherwise = acc
        (UserSummary k _ _ _ _ _ ) = s  -- !!
```

The pattern `(UserSummary k _ _ _ _ _) = s` shadows the `k` from the
guard. It's almost certainly a bug.

**Alternatives.**
- **α. Use named field accessors.** `userId' s == k`. The current
  `s` is a `UserSummary`; we just ask for its `userId'` field.
- **β. Use a where-binding with the destructured field.**
- **γ. Use `RecordWildCards` properly.** `@(UserSummary{userId' = k', ..}) <- s`
  is the right syntax.

**Resolution.** α. The fix is one line. The point of the demo is
*legible* type-driven code; shadowing violates that. The repo
should be fixed before any production usage.

---

### C1.5 — Where to put `IO`?

**Challenge.** The Haskell demo uses plain `IO`. In production, plain
`IO` makes testing painful — you can't inject a fake clock or a
fake filesystem without `mockery`.

**Alternatives.**
- **α. `mtl` / `transformers`.** `MonadIO`, `MonadReader`, etc.
  Ubiquitous, type-class based, sometimes hard to read.
- **β. `RIO` (the [`rio`](https://hackage.haskell.org/package/rio) package).**
  Concrete record-of-functions, no type classes. Used by the
  Haskell community as the modern alternative.
- **γ. Plain `IO` with a `Clock` parameter.** Cheap, explicit, no
  library.

**Resolution.** γ in the demo, β in production. The `Clock` type
in `Audit.scala` is the equivalent — the effect is parameterized,
not abstracted into a type class. It's the "least amount of magic"
choice.

---

## Part 2 — The Scala 3 template

### C2.1 — ZIO vs. cats-effect

**Challenge.** Both are excellent typed-effect libraries. The
ecosystem is split.

**Alternatives.**
- **α. cats-effect + cats.** Older, broader, more type-class
  machinery. Used by `fs2`, `http4s`, `doobie`.
- **β. ZIO 2.** Newer, single concrete data type, no type classes
  in user code. Used by `zio-http`, `zio-sql`, `caliban`.
- **γ. `Future` (legacy).** "Just give me a thread." Loses typed
  errors, races, and structured concurrency.

**Resolution.** β. ZIO's `ZIO[R, E, A]` is one type. You don't
need to know what `Sync` or `Concurrent` are. The error channel
is explicit. For an "Elite Generalist" demo, ZIO wins on
readability.

**Known limitation.** ZIO's `ZLayer` graph can get hairy in
large apps. We use it minimally: `Clock` is one layer, that's it.

---

### C2.2 — `opaque type` vs. value class

**Challenge.** We want `UserId`, `TxId`, `ActorId` to be
*nominal* types — a `UserId` and a `String` are not assignable to
each other. Scala has three ways.

**Alternatives.**
- **α. `case class UserId(s: String)`.** Boxed, allocates. 24
  bytes per id. Common OOP pattern.
- **β. `opaque type UserId = String`.** Zero allocation, full
  type safety. The compiler hides the representation outside
  the companion object. Scala 3 only.
- **γ. `value class UserId(val s: String) extends AnyVal`.**
  Zero allocation, but has known issues with type inference
  and pattern matching.

**Resolution.** β. `opaque type` is the Scala 3 answer to all
three problems. It's compile-time-only; the JVM sees a `String`.

---

### C2.3 — `enum` vs. sealed trait

**Challenge.** `Currency` is a closed set of four cases. We want
the compiler to warn if a `match` is non-exhaustive.

**Alternatives.**
- **α. Sealed trait + case objects.** The old way. Verbose.
- **β. Scala 3 `enum`.** `enum Currency { case EUR, USD, GBP, JPY }`.
  Automatically sealed, automatic exhaustiveness, derives
  `JsonCodec`.

**Resolution.** β. Five lines, full exhaustiveness, JSON codec
derived.

---

### C2.4 — The `Pipeline` algebra

**Challenge.** We wanted a `Pipeline[A, B]` type with `>>`
composition, to make the pipeline read as a left-to-right chain.
The current implementation has an `asInstanceOf` cast, which is
a code smell.

**Alternatives.**
- **α. Drop the `Pipeline` algebra.** Just use function
  composition. `auditLedger(now, users) compose normalize`. The
  current `Audit.scala` is mostly this.
- **β. Use kind-projector or a free monad.** More machinery,
  more abstraction, less readable.
- **γ. Use a free applicative.** Cleanest semantics, hardest
  to teach.

**Resolution.** α. Function composition is the abstraction.
The `Pipeline` type in the current code is a teaching device
that doesn't quite work; it should be either removed or
fixed properly. Marked `FUTURE-002`.

---

### C2.5 — Native image vs. JVM fat jar

**Challenge.** Phase 5 says "single static binary". On the JVM
that means GraalVM `native-image`.

**Alternatives.**
- **α. `sbt-assembly` fat jar.** One jar, runnable on any JVM.
  Slow startup, large footprint (~50 MB), no AOT.
- **β. GraalVM `native-image`.** AOT-compiled, ~10 MB binary,
  millisecond startup. Slow build (minutes), config is heavy.
- **γ. Just `sbt run`.** No build artifact, just the source.

**Resolution.** β for production, γ for the demo. The `build.sbt`
configures `Compile / nativeImage` so the path is documented.
For a real release, you'd run `sbt NativeImage/packageBin`.

---

## Part 3 — The Literate C template

### C3.1 — CWEB vs. noweb

**Challenge.** Two literate-programming tools for C: CWEB
(Knuth, 1984, requires TeX) and noweb (Norman Ramsey,
language-agnostic, simpler).

**Alternatives.**
- **α. CWEB.** The original. `ctangle` produces `.c`,
  `cweave` produces `.tex`. Beautifully typeset output, but
  TeX is a 200 MB dependency and few teams have it.
- **β. noweb.** Tangles to any language; weaves to TeX, HTML,
  or markdown. Smaller, more portable.
- **γ. Markdown with fenced code blocks.** Portable, renderable
  on GitHub, but loses the "tangle" step — the prose can
  diverge from the code.

**Resolution.** α. The `.w` file is portable to both CWEB and
noweb — the syntax is close enough that conversion is a script.
We picked CWEB for authenticity; `noweb` is a one-line switch
in the build script.

---

### C3.2 — IDE and GitHub support

**Challenge.** Most editors don't know `.w` files. GitHub
renders them as plain code.

**Alternatives.**
- **α. Vim/Emacs `cweb-mode`.** Best in class, but few use it.
- **β. Pre-render to `.c` + `.pdf`, commit both.** The `.w`
  is the source of truth, but the deliverables are visible
  on GitHub.
- **γ. GitHub Action that runs `cweave` on every push.** Always
  up to date, but adds CI complexity.

**Resolution.** β + γ. We commit `qsort.c` and `qsort.pdf`
alongside `qsort.w`. A GitHub Action is documented but not
included in the initial commit (so the repo is light).

---

### C3.3 — The "qsort is academic" objection

**Challenge.** Quicksort is the canonical literate-programming
example. Some will say it's too academic.

**Alternatives.**
- **α. Quicksort (Knuth).** The original example. The reader
  already knows what it should do, so they can focus on the
  *form*, not the *content*.
- **β. A real piece of systems code.** A hashtable, a memory
  allocator, a tiny HTTP parser. More relevant, but takes
  5× the page count.
- **γ. A small domain-specific program.** A lexer, a small
  expression evaluator. Best of both — concrete, not too long.

**Resolution.** α. The user can extend to β or γ in their own
fork. The point of the template is the *form*, not the
quicksort.

---

## Part 4 — The fake data

### C4.1 — How to rig the unknown-user path

**Challenge.** The pipeline has a `Maybe User` branch. The demo
must exercise it without the user having to manually edit data.

**Alternatives.**
- **α. Add a "rogue" user `u-rogue` to `users.json`.** Easy
  to miss. Looks like normal data.
- **β. Reference `u-9` from transactions but not from users
  (what we did).** Obvious gap. Forces the reader to think
  about it.

**Resolution.** β. `tx-0023` and `tx-0031` reference `u-9`.
The reader can't miss it. The report shows `u-9` with
`unknown: true, name: "?"`.

---

### C4.2 — Currency mixing without FX

**Challenge.** Real ledgers are multi-currency. A naive sum
adds EUR cents to USD cents.

**Alternatives.**
- **α. Convert to a base currency.** Need an FX rate source.
  Out of scope for a demo.
- **β. Sum by currency.** The schema already has a `currency`
  field. The demo just sums across currencies (and flags this
  as a known limitation).
- **γ. Pick one currency.** Boring, doesn't show the
  multi-currency shape of the data.

**Resolution.** β. The totals in `reports/audit.json` are
summed across currencies — that's a known limitation. The
property tests use a single currency to avoid the issue.

---

### C4.3 — Hand-craft vs. generated

**Challenge.** Synthetic data can mislead if it's too uniform
or too random.

**Alternatives.**
- **α. Hand-craft 35 plausible transactions.** Pedagogical,
  edge cases visible.
- **β. Generate from a distribution.** Realistic-looking, but
  less pedagogical.

**Resolution.** α. The `memo` column is human-readable; the
reader can scan the file and see the structure. Generated
data would have lorem-ipsum memos.

---

## Decision log summary

| # | Decision | Rationale | Risk | Status |
|---|---|---|---|---|
| C0.1 | Pure core, typed boundary | Best of both worlds | Heavy effect types | adopted |
| C0.2 | Hybrid test style | Cover both shapes | More tests to write | adopted |
| C0.3 | 9 transitive deps | Audit-friendly | Discipline required | adopted |
| C0.4 | Scala as gateway | Familiar syntax | Two languages to maintain | adopted |
| C0.5 | Domain-driven modules | Compiler-enforced architecture | Upfront design cost | adopted |
| C1.1 | `Money` newtype | Zero-cost type safety | Boilerplate | adopted |
| C1.2 | `MiniMap` in demo, `Data.Map.Strict` in prod | Teaching device | O(n) lookups | adopted |
| C1.3 | QuickCheck full range (FUTURE-001) | Cover debit branch | Slower tests | **resolved (#1, PR #4)** |
| C1.4 | Named field accessors (FUTURE-003) | Avoid shadowing | — | **resolved (#3, PR #4)** |
| C1.5 | `Clock` parameter | Least amount of magic | No abstract effect | adopted |
| C2.1 | ZIO over cats-effect | More concrete | Smaller ecosystem for some libs | adopted |
| C2.2 | `opaque type` | Zero allocation | Scala 3 only | adopted |
| C2.3 | `enum` | Cleanest syntax | Scala 3 only | adopted |
| C2.4 | Drop `Pipeline` algebra (FUTURE-002) | Function composition suffices | — | **resolved (#2, PR #4)** |
| C2.5 | GraalVM `native-image` in prod | Single static binary | Slow build | adopted |
| C3.1 | CWEB | Authenticity | TeX dependency | adopted |
| C3.2 | Pre-render + commit | GitHub visibility | Slight duplication | adopted |
| C3.3 | Quicksort | Canonical example | Looks academic | adopted |
| C4.1 | Reference `u-9` from txs | Pedagogical | Requires thought | adopted |
| C4.2 | Sum across currencies (limitation) | Demo simplicity | Wrong totals | adopted (limitation) |
| C4.3 | Hand-craft | Pedagogical | Less realistic | adopted |

---

## Iteration 1 — closing the FUTURE-NN issues

> **Status:** all three resolved. PR #4 squash-merged as commit `2c0d4cf`.

This is what happened between the initial commit and now.

### Resolution of FUTURE-001 (#1)

**Before.** `Spec.hs` had:

```haskell
instance Arbitrary Money where
  arbitrary = Money . getNonNegative <$> arbitrary
```

`prop_auditPreservesTotal` was only really testing the *credit* branch.
The debit side relied on the shrinking path to find a counter-example,
which it did not.

**After.**

```haskell
-- | FUTURE-001: cover the full cent range (debits as well as credits) so that
--   'prop_auditPreservesTotal' actually exercises the debit branch.
instance Arbitrary Money where
  arbitrary = Money <$> choose (-1_000_000, 1_000_000)
```

The CI workflow (`.github/workflows/ci.yml`) has a **regression guard**
that fails the build if the line `choose (-1_000_000, 1_000_000)` is
ever reverted to `NonNegative`. The future caught the past.

### Resolution of FUTURE-002 (#2)

**Before.** `Audit.scala` had a `Pipeline[A, B]` trait with a `>>`
operator, and an `examplePipeline` that used an `asInstanceOf` cast
to paper over a type error in the composition chain.

**After.** Dropped the trait entirely. Replaced with a `Stage[A, B]`
type alias (= `A => B`), a `composeAudit` combinator, and an
`auditPipeline` that wires the four stages in a single expression.
No `asInstanceOf` in the code. The CI workflow has a regression
guard for this too.

### Resolution of FUTURE-003 (#3)

**Before.** `Audit.hs` had a `where`-binding

```haskell
lookupUser = foldr step Nothing
  where step s acc | userId' s == k = Just s | otherwise = acc
        (UserSummary k _ _ _ _ _ ) = s   -- BUG: shadows k, never used
```

The pattern binding `(UserSummary k _ _ _ _ _) = s` was dead code that
shadowed the guard's `k` and was never read. It compiled, but the
intent was confused.

**After.** The `where`-binding is gone. The guard's `userId' s == k`
uses the right field. The CI workflow has a regression guard against
the pattern coming back.

### What this iteration taught us

1. **The CI regression guards are the design log's teeth.** Without
   them, the next contributor can quietly revert a fix and the
   discipline erodes.
2. **Manual `Closes` in PR comments does not auto-close issues.**
   We had to close #1, #2, #3 explicitly. Future PRs should put
   `Closes #N` in the *body*, not just a comment.
3. **The discipline is the product.** A repo that admits its bugs
   and fixes them in a single PR is more trustworthy than one that
   pretends to be perfect on the first commit.

---

## What this log is not

This log is not a justification. It's a *record* — including the
choices that turned out to be wrong or weak, and the iterations
that closed them.

The discipline is the product. The discipline includes admitting
when the discipline slipped, and writing the regression guard so
it doesn't slip again.
