# Where to Expose and Practice the Elite Generalist Templates

Three concentric rings: **publish the code**, **practice on real data**, **share
the philosophy**.

---

## 1. Code repositories — where the templates live

### 1.1 Haskell — Hackage & GitHub

| What | Where | Why |
|---|---|---|
| `Audit.hs` + `Spec.hs` as a published package | **[Hackage](https://hackage.haskell.org/)** (the Haskell community package server) | First-party registry; every package is cryptographically signed; cabal-install verifies before install. The "9 transitive deps" claim in the workflow doc is provable. |
| Source mirror | **[GitHub](https://github.com/)** under your own namespace (`elite-generalist/audit-hs`) | Lets people file issues, send PRs, see the property suite fail before they fix. Use **signed commits** (Sigstore / GPG). |
| CI | **[GitHub Actions](https://github.com/features/actions)** with `haskell-actions/setup` | Runs the property suite on every commit. The green badge is the proof. |
| Doc site | **Hackage + Haddock** (auto-generated from your doc comments) | The doc IS the source. Phase 3. |
| Reproducible builds | **[`haskell-flake`](https://github.com/srid/haskell-flake)** on Nix | Same commit, byte-identical binary. Phase 4. |

> **Real-world Hackage examples for the techniques used:**
> - `aeson` (JSON), `cassava` (CSV), `QuickCheck` (properties), `text`, `bytestring`.
> - For property-based testing of pipelines: [`tasty-quickcheck`](https://hackage.haskell.org/package/tasty-quickcheck).
> - For streaming CSV: [`cassava`](https://hackage.haskell.org/package/cassava).
> - For pure JSON: [`aeson`](https://hackage.haskell.org/package/aeson).

### 1.2 Scala 3 — Maven Central & Sonatype

| What | Where | Why |
|---|---|---|
| `Audit.scala` + `AuditSpec.scala` | **[Maven Central](https://central.sonatype.com/)** via Sonatype OSSRH | First-party registry; jars are PGP-signed; SBT resolves with a lockfile (`dependency-lock`). |
| Source mirror | **[GitHub](https://github.com/)** (`elite-generalist/audit-scala`) | |
| CI | **[GitHub Actions](https://github.com/features/actions)** with `sbt` + `sbt-native-image` | GraalVM `native-image` produces a single static binary — Phase 5 in the strongest form. |
| Doc site | **Scaladoc** (auto-generated, hosted on GitHub Pages) | Scaladoc on `opaque type` aliases and `enum` cases is the literate layer. |
| Reproducible builds | **`sbt-projectmatrix`** + lockfile | |

> **Real-world Scala libs for the techniques used:**
> - [`zio`](https://zio.dev/) — typed effects, async, no `Future` soup.
> - [`zio-json`](https://zio.dev/zio-json/) — codec derivation for case classes and enums.
> - [`scalacheck`](https://www.scalacheck.org/) — property-based testing.
> - [`zio-test`](https://zio.dev/zio-test/) — assertions in the same monad as production code.
> - For pure pipelines: [`cats`](https://typelevel.org/cats/) + [`cats-effect`](https://typelevel.org/cats-effect/), or [Monix](https://monix.io/).

### 1.3 Literate C — `cweb` / `noweb` & literateprogramming.com

| What | Where | Why |
|---|---|---|
| `qsort.w` source | **GitHub** (the `.w` file is the artifact) | The `.c` is generated; only the `.w` is reviewed. |
| Built PDF | **GitHub Pages** with `cweave` → `pdflatex` | The PDF is the manual. |
| Build system | **`noweb` (Norman Ramsey)** or **`cweb` (Knuth)** | Both support the literate workflow; `cweb` is the original. |
| Catalogue | **[literateprogramming.com](https://www.literateprogramming.com/)** | The community hub. Lists dozens of tools and exemplars. |

> **Real-world literate-C exemplars:**
> - *Literate Programming* (Knuth, Stanford CSLI) — the `web` system.
> - *Programming Pearls* and *TAOCP* — `w` files that produced the books.
> - [`noweb`](https://www.cs.tufts.edu/~nr/noweb/) — language-agnostic literate tool.
> - [`clinear`](https://github.com/clinear/) — modern alternative.

---

## 2. Data repositories — where to *practice* the pipeline

Real datasets that exercise exactly the "enrich + aggregate + flag" shape of
this demo. Drop them in `data/`, point the pipeline at them, see the report.

### 2.1 Open financial ledgers

| Dataset | URL | What it tests |
|---|---|---|
| **Plaid Sandbox Transactions** | [`https://plaid.com/docs/sandbox/test-credentials/`](https://plaid.com/docs/sandbox/test-credentials/) | Bank-style ledger. Excellent for unknown-user joins. |
| **Synthetic Mass Pay ledger** | [`https://www.kaggle.com/datasets/ealtman2019/credit-card-transactions`](https://www.kaggle.com/datasets/ealtman2019/credit-card-transactions) | 20M+ transactions, ideal for property-based testing at scale. |
| **PaySim** (mobile money) | [`https://www.kaggle.com/datasets/ealaxi/paysim1`](https://www.kaggle.com/datasets/ealaxi/paysim1) | Synthetic fraud, perfect for the `flaggedCount` branch. |
| **IEEE-CIS Fraud** | [`https://www.kaggle.com/c/ieee-fraud-detection`](https://www.kaggle.com/c/ieee-fraud-detection) | Real-world fraud labels, the hardest possible property tests. |

### 2.2 Open user/directory data (for the `enrichWith` join)

| Dataset | URL |
|---|---|
| **OpenAddresses** | [`https://openaddresses.io/`](https://openaddresses.io/) |
| **OpenStreetMap nominatim** | [`https://nominatim.org/`](https://nominatim.org/) |
| **RestCountries** | [`https://restcountries.com/`](https://restcountries.com/) — ISO-3166 / currency lookup, fits the `Country` field. |
| **Faker** (synthetic generators) | [`https://github.com/joke2k/faker`](https://github.com/joke2k/faker) — Python; the Haskell equivalent is [`hfake`](https://hackage.haskell.org/package/hfake) and Scala equivalent is [`scalacheck-shapeless`](https://github.com/alexarchambault/scalacheck-shapeless). |

### 2.3 Open standards & schemas

| Source | URL | Use |
|---|---|---|
| **ISO-4217** (currency codes) | [`https://www.iso.org/iso-4217-currency-codes.html`](https://www.iso.org/iso-4217-currency-codes.html) | The `Currency` enum in the templates is hand-rolled; production would derive it from this list. |
| **ISO-20022** (financial messaging) | [`https://www.iso20022.org/`](https://www.iso20022.org/) | Real bank schema — `pain.001`, `camt.053` — maps cleanly onto the `Transaction` record. |
| **JSON Schema** test suite | [`https://github.com/json-schema-org/`](https://github.com/json-schema-org/) | For round-tripping the report JSON. |
| **CSV on the Web** | [`https://www.w3.org/TR/tabular-metadata/`](https://www.w3.org/TR/tabular-metadata/) | For declarative CSV → typed records. |

### 2.4 Open benchmarking corpora (for "verify at scale")

| Source | URL |
|---|---|
| **QuickCheck variants benchmark** | [`https://hackage.haskell.org/package/QuickCheck`](https://hackage.haskell.org/package/QuickCheck) |
| **ScalaCheck gists & repos** | [`https://github.com/rallyhealth/scalacheckz`](https://github.com/rallyhealth/scalacheckz) etc. |
| **Hypothesis (Python)** | [`https://hypothesis.readthedocs.io/`](https://hypothesis.readthedocs.io/) — same philosophy, different language. |
| **The Art of Property-Based Testing** | [`https://github.com/jlink/property-based-testing-stateful`](https://github.com/jlink/property-based-testing-stateful) |

---

## 3. Where to *talk about it* — community channels

| Channel | Why |
|---|---|
| **[r/ProgrammingLanguages](https://www.reddit.com/r/ProgrammingLanguages/)** | Type-driven + literate C topics. |
| **[r/haskell](https://www.reddit.com/r/haskell/)**, **[r/scala](https://www.reddit.com/r/scala/)** | Show the templates, gather feedback. |
| **[Hacker News](https://news.ycombinator.com/)** | "Show HN: Elite Generalist pipeline" with a link to GitHub. |
| **[Lobsters](https://lobste.rs/)** | Strong literate-programming and FP communities. |
| **[LambdaMOO / #haskell IRC / Libera.chat](https://libera.chat/)** | Real-time Q&A. |
| **[Scala Discord](https://discord.com/invite/scala)** | The ZIO + ScalaCheck crowd. |
| **[Dev.to](https://dev.to/)** and **[Hashnode](https://hashnode.com/)** | Long-form posts — "How I replaced an enterprise pipeline with 9 deps". |
| **[The Art of Programming](https://www.codingame.com/)** | For gamified practice. |

---

## 4. Quick-start: a one-page recipe

```bash
# Clone the templates
git clone https://github.com/<you>/elite-generalist.git
cd elite-generalist

# Run the property suite (Phase 2)
cd templates/haskell && cabal test && cd -

# Run the ScalaCheck suite (Phase 2)
cd templates/scala && sbt test && cd -

# Build the literate manual (Phase 3)
cweave templates/literate-c/qsort.w
pdflatex qsort.tex
# -> qsort.pdf is the manual, qsort.c is the program.

# Drop in real data (Phase 1)
wget https://.../paysim.csv -O data/transactions.csv

# Run the audit (Phase 5)
cabal run audit-cli -- data/transactions.csv data/users.json reports/audit.json
```

If anything in the runbook above fails, you have a concrete test to write
*before* you change the code. That's the discipline. The discipline is
the product.
