# The Elite Generalist Pipeline

> One developer. One local agentic environment. Revenues that used to require
> an enterprise department — captured by replacing **manual state management**
> with **declarative composition**.

---

## The Four Hidden Costs the Pipeline Eliminates

| Hidden cost | Where it comes from | How this pipeline kills it |
|---|---|---|
| **Documentation drift** | Comments die, READMEs rot, runbooks lag | Code is the doc (Literate C, Haddock, Scaladoc on pure types) |
| **Cloud bloat** | Managed services, sidecar microservices, queues-for-queues | Local-first, deterministic, reproducible builds |
| **Supply-chain vulnerabilities** | 1,200 transitive npm/pip deps | Minimal dep surface, vetted stdlib + 5–10 audited libs |
| **State bugs** | Mutable refs, threading, race conditions | Pure functions + algebraic effects; effects are typed and explicit |

The pipeline is a **5-phase flywheel**. Every artifact is either a theorem,
a test, or a piece of generated documentation — never a comment that can rot.

---

## Phase 0 — Specify (Type-Driven Contract)

**Question of the phase:** *"What is the smallest pure function that could
not lie?"*

```haskell
-- /templates/haskell/Audit.hs
auditLedger :: [Transaction] -> AuditReport
auditLedger = ...
```

You don't write `auditLedger :: [Transaction] -> AuditReport` and then go
build infrastructure. You write **the type first**, then ask the type what
it needs. The compiler is your first reviewer.

**Deliverable:** A signature per public function. The signatures are the
spec. Comments are not allowed to disagree with them — they cannot.

---

## Phase 1 — Compose (Declarative Pipeline)

The pipeline is `f . g . h` with **no shared mutable state** between stages.
Each stage takes a value, returns a value. Composition is the abstraction.

```haskell
-- The whole "service" is a one-liner.
main :: IO ()
main = do
  raw   <- readTransactions "data/transactions.csv"
  let report = auditLedger          -- pure
            . enrichWith users      -- pure
            . normalize             -- pure
            $ raw
  writeReport "reports/audit.json" report
```

There is no `Service`, no `Controller`, no `Repository` class. There is
a function. **State is threaded, not hidden.**

The Scala equivalent uses `ZIO` effects (typed IO) so the same shape is
preserved but IO is explicit at the boundary:

```scala
val audit: ZIO[Env, AuditError, AuditReport] =
  for
    raw    <- loadTransactions("data/transactions.csv")
    users  <- loadUsers("data/users.json")
    report =  auditLedger
            .compose(enrichWith(users))
            .compose(normalize)
            .apply(raw)
    _      <- writeReport("reports/audit.json", report)
  yield ()
```

---

## Phase 2 — Verify (Properties, Not Just Examples)

Property-based testing (QuickCheck / ScalaCheck) replaces example-based
unit tests. The theorem is the spec; the property is the test.

```haskell
prop_auditPreservesTotal :: [Transaction] -> Property
prop_auditPreservesTotal txs =
  sumCredits (auditLedger txs)
    === sumCredits (normalize txs)
```

You don't write "given [tx1, tx2], expect X". You write *"for all
transactions, the audit preserves the credit sum."* The test generator
finds the counter-example. Bugs get hunted by the compiler.

---

## Phase 3 — Document (Literate by Construction)

Three styles, one rule — **the executable IS the document**.

- **Haskell** → Haddock comments on the type signatures.
- **Scala 3** → Scaladoc on the `enum`s (algebraic types) and `opaque type` aliases.
- **C / systems code** → **Literate C** (CWEB / noweb). The `.w` file weaves
  prose and C together; the compiler runs over the tangled C; the reader
  reads the woven TeX/HTML. There is **one source of truth**.

```c
/* /templates/literate-c/qsort.w — Knuth's quicksort, in literate form */
@* The partition step.
   We choose the last element as pivot; this costs O(n) comparisons.
   On return, all elements before |i| are ≤ |a[i]| and all after are >.
   @<Partition@>=
@=
```

No README, no Confluence page, no "onboarding guide" that goes stale in
six months. The build artifact *is* the manual.

---

## Phase 4 — Package (Minimal, Reproducible, Auditable)

- **Pinned dependency set** (cabal.project.freeze, dependency-lock).
- **No SaaS at runtime** — single static binary, runs offline.
- **SBOM generated from the lock file**, not from a vendor portal.
- **Reproducible build** — same commit, byte-identical binary.

The dependency surface of the demo in this folder:

```
haskell:  base, aeson, text, QuickCheck, bytestring, cassava   (6)
scala:    zio, zio-json, scalacheck                            (3)
c:        stdlib only                                          (0)
```

Total: **9 third-party packages**, all from first-party registries
(Hackage, Maven Central) and all with cryptographic signatures.

---

## Phase 5 — Distribute (Local Agent, Not a Cloud)

The artifact lands as a binary on the user's machine, plus the source.
The local agentic environment — the AI working alongside the developer —
runs the pipeline end-to-end from a natural-language brief.

```
$ agent "audit Q3 transactions, flag any with negative net of > -50"
```

The agent invokes `auditLedger`, runs the property suite, and renders
the literate documentation. **No deployment, no Kubernetes, no
Datadog invoice.** That's the "Elite Generalist" arbitrage.

---

## The Flywheel

```
        ┌──────────────┐
        │   Specify    │  type signatures
        └──────┬───────┘
               ▼
        ┌──────────────┐
        │   Compose    │  f . g . h
        └──────┬───────┘
               ▼
        ┌──────────────┐
        │   Verify     │  property-based
        └──────┬───────┘
               ▼
        ┌──────────────┐
        │   Document   │  code = doc
        └──────┬───────┘
               ▼
        ┌──────────────┐
        │   Package    │  minimal, signed
        └──────┬───────┘
               ▼
        ┌──────────────┐
        │  Distribute  │  local agent
        └──────┬───────┘
               │
               └───── feedback ──► Specify (next iteration)
```

Every revolution tightens the loop: smaller spec → cleaner composition
→ stronger properties → tighter doc → smaller binary. The "Elite
Generalist" doesn't outwork the enterprise — they out-discipline it.
