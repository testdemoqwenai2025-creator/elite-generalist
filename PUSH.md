# Pushing to GitHub

The local repo is committed and clean (21 files, 1 commit, 2,453 lines).
Pushing to GitHub requires your GitHub credentials, so this file gives
you the exact commands to run on your own machine.

---

## 1. Pick a repo name

I recommend **one** of the following. Rationale below.

| Rank | Name | Rationale |
|---|---|---|
| **★ primary** | `elite-generalist` | Matches the project, searchable, fits the "single brand" framing. |
| alternative | `discipline-as-product` | Philosophical anchor of the README. Memorable, but vague in search. |
| alternative | `single-bin-enterprise` | The clearest pun on "single binary replaces enterprise pipeline". Cute but distinctive. |
| alternative | `type-driven-audit-pipeline` | Pure descriptive. Best for technical search. |
| alternative | `generalist-arbitrage` | Captures the "one person captures a team's revenue" framing. |

> **My pick:** `elite-generalist` — it's the project name, easy to find,
> and works equally well on the README header and the Hackage upload form
> if you later publish there as `elite-generalist-audit`.

---

## 2. Push (if you have `gh` CLI)

```bash
# install gh: https://cli.github.com/  (or use apt/brew)

# from the project root
cd elite-generalist

# log in once
gh auth login

# create the repo and push in one command
gh repo create elite-generalist \
  --public \
  --description "From manual state management to declarative composition: pure FP pipelines, literate C, property-based tests. One dev replaces a department." \
  --source=. \
  --remote=origin \
  --push
```

That's it. The repo is now at
`https://github.com/<your-username>/elite-generalist`.

---

## 3. Push (if you don't have `gh`)

```bash
cd elite-generalist

# 1. Create an empty repo on github.com first (do NOT init with README, .gitignore, or license — we have them)
#    https://github.com/new  -> name: elite-generalist, public, no init

# 2. Add the remote
git remote add origin git@github.com:<your-username>/elite-generalist.git

# 3. Push
git push -u origin main
```

---

## 4. Recommended post-push setup

Once the repo is up, do these in the GitHub UI (or with `gh`):

```bash
# 1. Topics — help people find it
gh repo edit --add-topic haskell,scala,functional-programming,property-based-testing,literate-programming,data-engineering,type-driven-design,cweb,noweb,zio,quickcheck

# 2. About / description
gh repo edit --description "From manual state management to declarative composition: pure FP pipelines, literate C, property-based tests."

# 3. Homepage (after you deploy pipeline.html somewhere)
gh repo edit --homepage "https://<your-username>.github.io/elite-generalist/pipeline.html"

# 4. Enable Issues (so FUTURE-001 etc. land in the tracker)
gh repo edit --enable-issues

# 5. (optional) GitHub Pages for pipeline.html
gh repo edit --enable-pages --branch main --path /

# 6. Suggested labels
gh label create "design-decision"  --color "1d76db" --description "Captured in DESIGN.md"
gh label create "future-work"      --color "fbca04" --description "FUTURE-NN item"
gh label create "good-first-issue" --color "7057ff" --description "Beginner-friendly"
gh label create "docs"             --color "0e8a16" --description "Documentation only"
gh label create "bug"              --color "d73a4a" --description "Confirmed bug"
```

---

## 5. Future-001, -002, -003 — the issues to file

The DESIGN.md has a "FUTURE-NN" series. File them right after the push:

```bash
gh issue create --title "FUTURE-001: QuickCheck arbitrary for Money should cover the full cent range (not NonNegative)" \
  --label "design-decision,future-work" \
  --body "See DESIGN.md C1.3. Currently prop_auditPreservesTotal only deeply tests the credit branch because Arbitrary Money uses NonNegative. Switch to choose(-1_000_000, 1_000_000) and document the test slowdown."

gh issue create --title "FUTURE-002: Audit.scala Pipeline algebra has a suspicious asInstanceOf cast" \
  --label "design-decision,future-work" \
  --body "See DESIGN.md C2.4. Either remove the Pipeline type and use plain function composition, or fix the types so the cast is gone."

gh issue create --title "FUTURE-003: Audit.hs lookupUser helper uses RecordWildCards pattern that shadows the guard's k" \
  --label "bug,design-decision" \
  --body "See DESIGN.md C1.4. The line '(UserSummary k _ _ _ _ _ ) = s' inside the step function shadows the outer 'k' parameter. Replace with named field accessors (userId' s == k)."
```

These three issues are the **honest** part of the design log: bugs we
caught while writing the doc, filed before the codebase pretends to be
perfect.

---

## 6. If you want to publish to Hackage / Maven Central

See [`repositories.md`](repositories.md) for the long version. Short
version:

```bash
# Hackage (Haskell)
cabal v2-haddock --haddock-for-hackage --enable-doc
cabal v2-haddock --haddock-for-hackage --haddock-options="--hyperlinked-source" --haddock-options="--no-warnings"
cabal upload --documentation --publish-dir=dist-newdocs/built-doc/audit-X.Y.Z-doc

# Maven Central (Scala) — needs sonatype credentials
sbt +publishSigned
sbt sonatypeBundleRelease
```

Both registries require you to set up `~/.cabal/config` and
`~/.sbt/1.0/sonatype.sbt` with your credentials first. The "Elite
Generalist" is meant to ship from your machine, not from CI — local
agent, local release.
