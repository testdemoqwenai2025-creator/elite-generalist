# Elite Generalist — A Workflow & Template Kit

> One developer. One local agentic environment. Revenues that used to require
> an enterprise department — captured by replacing **manual state management**
> with **declarative composition**.

## Read in this order

1. **[`DESIGN.md`](DESIGN.md)** — the pre-project decision log. Every
   challenge we hit, the alternatives we weighed, the resolution we picked,
   and the things we got wrong. Read this *first*; it tells you why the
   templates are shaped the way they are.
2. **[`workflow/elite-generalist-pipeline.md`](workflow/elite-generalist-pipeline.md)**
   — the 5-phase flywheel (Specify → Compose → Verify → Document → Package/Distribute).
3. **[`pipeline.html`](pipeline.html)** — open in a browser for the visual
   rendering of the same content.
4. **[`repositories.md`](repositories.md)** — Hackage, Maven Central,
   literate-C, financial datasets, and community channels.
5. The templates themselves.

```
elite-generalist/
├── README.md                              ← you are here
├── DESIGN.md                              ← READ FIRST — pre-project design log
├── LICENSE                                ← MIT
├── pipeline.html                          ← self-contained visual rendering
├── workflow/
│   └── elite-generalist-pipeline.md       ← the 5-phase flywheel
├── templates/
│   ├── haskell/
│   │   ├── Audit.hs                       ← pure declarative pipeline
│   │   └── Spec.hs                        ← property-based test suite
│   ├── scala/
│   │   ├── Audit.scala                    ← algebraic types + ZIO
│   │   └── AuditSpec.scala                ← ScalaCheck properties
│   └── literate-c/
│       └── qsort.w                        ← Knuth-style literate program
├── data/
│   ├── transactions.csv                   ← 35 fake transactions
│   ├── transactions.json                  ← same, for the Scala pipeline
│   └── users.json                         ← 8 fake users (note: u-9 is missing)
├── project/
│   ├── package.yaml                       ← Haskell (hpack) — 3 direct deps
│   ├── cabal.project                      ← frozen, reproducible
│   └── build.sbt                          ← Scala 3 — 3 direct deps
├── examples/
│   ├── run.sh                             ← the local-agent driver
│   └── haskell/Main.hs                    ← CLI driver
├── reports/
│   └── audit.json                         ← sample output (u-9 flagged)
└── repositories.md                        ← where to publish & practice
```

## The five phases, in one breath

| # | Phase | What you produce | Hidden cost it kills |
|---|---|---|---|
| 0 | **Specify** | A type signature per public function | — |
| 1 | **Compose** | `auditLedger . enrichWith users . normalize` | state bugs |
| 2 | **Verify** | `prop_auditPreservesTotal` and friends | test rot |
| 3 | **Document** | Haddock / Scaladoc / `cweave`'d PDF | documentation drift |
| 4 | **Package** | 9 transitive deps, all signed | supply chain |
| 5 | **Distribute** | single static binary, no SaaS | cloud bloat |

## Try it

```bash
# 1. Verify
cd templates/haskell && cabal test && cd ../../
cd templates/scala  && sbt test    && cd ../../

# 2. Document (literate C -> PDF + .c)
cweave templates/literate-c/qsort.w && pdflatex qsort.tex

# 3. Audit the fake ledger
cabal run audit-cli -- \
  data/transactions.csv data/users.json reports/audit.json
```

The fake data is intentionally rigged: `tx-0023` and `tx-0031` reference
`u-9`, which is **not** in `users.json`. Run the pipeline and the report
will show the unknown user flagged with `unknown: true` and `name: "?"`.
That's the kind of bug an enterprise pipeline emits *after* a release;
the property tests catch it at compile time.

## Why this is the "Elite Generalist" arbitrage

| Enterprise team | You (this repo) |
|---|---|
| 1,200 transitive npm packages | 9 Hackage + Maven packages |
| Microservice A talks to B talks to queue | A pure function `f . g . h` |
| 40-page runbook, 6-month-stale | Scaladoc on `opaque type` — the doc IS the type |
| Datadog / NewRelic invoice | Printf on stdout, no bill |
| SRE on call for stateful services | Single static binary, restart-and-forget |
| Quarterly security review | `cabal.project.freeze` + Maven lockfile + signed commit |

The arbitrage is not "cheaper" — it's **discipline sold as product**.

## Where to publish / practice

See [`repositories.md`](repositories.md) for Hackage, Maven Central, open
financial datasets (Plaid sandbox, PaySim, IEEE-CIS fraud), open user
directories, and the literate-programming community hubs.

## License

MIT. Take it, fork it, ship it.
