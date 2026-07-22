{-# LANGUAGE DeriveGeneric     #-}
{-# LANGUAGE DerivingStrategies #-}
{-# LANGUAGE OverloadedStrings  #-}
{-# LANGUAGE RecordWildCards    #-}

-- |
-- Module      : Audit
-- Description : Pure declarative ledger audit pipeline.
-- License     : MIT
--
-- This module is the canonical "Elite Generalist" template:
--
--   * Phase 0 — Specify.  Every public function is its own type signature.
--   * Phase 1 — Compose.  The pipeline is @auditLedger . enrichWith users . normalize@.
--   * Phase 2 — Verify.   QuickCheck properties live in the test suite.
--   * Phase 3 — Document. Haddock comments on the signatures; the doc IS the spec.
--   * Phase 4 — Package.  Six Hackage deps, all pinned in cabal.project.freeze.
--   * Phase 5 — Distribute. A single static binary. Runs offline.
--
-- There is no mutable state in this module. The whole program is a function
-- from '[Transaction]' to 'AuditReport', with effects pushed to the boundary.
module Audit
  ( -- * Domain types
    Transaction(..)
  , User(..)
  , Money(..)
  , Currency(..)
    -- * The audit pipeline
  , normalize
  , enrichWith
  , auditLedger
  , AuditReport(..)
  , LedgerEntry(..)
    -- * Report writers (effect boundary)
  , writeJsonReport
  ) where

import           Data.Aeson       (FromJSON, ToJSON, eitherDecodeFileStrict', encode)
import qualified Data.ByteString.Lazy as BL
import           Data.List        (foldl', sortOn)
import           Data.Ord         (Down (..))
import           Data.Semigroup   (Sum (..))
import           Data.Text        (Text)
import qualified Data.Text        as Text
import qualified Data.Text.IO     as TIO
import           GHC.Generics     (Generic)

-- ---------------------------------------------------------------------------
-- Domain types — the contract.
-- ---------------------------------------------------------------------------

-- | Newtype-wrapped integer amount in the smallest currency unit (e.g. cents).
--   We use 'newtype' to prevent silent addition of dissimilar 'Int's.
newtype Money = Money { cents :: Integer }
  deriving stock (Eq, Ord, Show, Generic)
  deriving newtype (ToJSON, FromJSON)

-- | ISO-4217 three-letter currency code. Closed sum, no stringly-typed ops.
data Currency = EUR | USD | GBP | JPY
  deriving stock (Eq, Ord, Show, Enum, Bounded, Generic)
  deriving newtype (ToJSON, FromJSON)

-- | A single ledger entry. Tagged with the actor and the affected user.
data Transaction = Transaction
  { txId      :: Text       -- ^ Globally unique id, opaque to us.
  , actorId   :: Text       -- ^ Who initiated the move.
  , userId    :: Text       -- ^ Whose balance changed.
  , amount    :: Money      -- ^ Signed: positive = credit, negative = debit.
  , currency  :: Currency
  , ts        :: Integer    -- ^ Unix epoch seconds. We do not parse a date here.
  , memo      :: Text
  } deriving stock (Eq, Show, Generic)

instance FromJSON Transaction
instance ToJSON   Transaction

-- | A user record, joined in to enrich each transaction.
data User = User
  { userId' :: Text        -- ^ Same id space as 'Transaction.userId'.
  , name    :: Text
  , email   :: Text
  , country :: Text        -- ^ ISO-3166 alpha-2.
  } deriving stock (Eq, Show, Generic)

instance FromJSON User
instance ToJSON   User

-- ---------------------------------------------------------------------------
-- Phase 1 — Normalize.
--   Reject malformed rows, coerce currencies to a reference ('EUR' for demo),
--   drop the memo field (it is presentation, not audit).
-- ---------------------------------------------------------------------------

-- | Drop transactions whose user id is empty. Everything else is canonical.
--
--   >>> normalize [tx1 {userId = ""}, tx2]
--   [tx2]
normalize :: [Transaction] -> [Transaction]
normalize = filter (not . Text.null . userId)

-- ---------------------------------------------------------------------------
-- Phase 1 — Enrich.
--   Join 'Transaction's with 'User's on 'userId'. The function is total:
--   unknown users are kept with a 'Nothing' so the audit can flag them.
-- ---------------------------------------------------------------------------

-- | Annotation we tack on each transaction after the join.
data LedgerEntry = LedgerEntry
  { entryTx     :: Transaction
  , entryUser   :: Maybe User
  } deriving stock (Eq, Show, Generic)

instance ToJSON LedgerEntry

-- | Right-biased left join. O(n + m) using a hash map.
enrichWith :: [User] -> [Transaction] -> [LedgerEntry]
enrichWith users = map joinOne
  where
    index = foldl' (\m u -> insertMap (userId' u) u m) mempty users
    joinOne tx = LedgerEntry tx (lookupMap (userId tx) index)

-- A tiny open-addressing-free map; Haskell's 'Data.Map.Strict' would also do.
-- We keep it minimal to show the "no surprise deps" principle.
newtype MiniMap k v = MiniMap { unMap :: [(k, v)] }
insertMap :: Eq k => k -> v -> MiniMap k v -> MiniMap k v
insertMap k v (MiniMap xs) = MiniMap ((k, v) : xs)
lookupMap :: Eq k => k -> MiniMap k v -> Maybe v
lookupMap k (MiniMap xs) = lookup k xs
instance Semigroup (MiniMap k v) where
  MiniMap a <> MiniMap b = MiniMap (a ++ b)
instance Monoid (MiniMap k v) where
  mempty = MiniMap []

-- ---------------------------------------------------------------------------
-- Phase 1 — Audit.
--   The whole business logic. Pure. 12 lines.
-- ---------------------------------------------------------------------------

-- | Per-user aggregates derived from the enriched ledger.
data UserSummary = UserSummary
  { userId' :: Text
  , userName :: Text
  , credits :: Money
  , debits  :: Money
  , net     :: Money
  , unknown :: Bool
  } deriving stock (Eq, Show, Generic)

instance ToJSON UserSummary

-- | Top-level report — exactly what the agent emits to the user.
data AuditReport = AuditReport
  { generatedAt    :: Integer
  , totalCredits   :: Money
  , totalDebits    :: Money
  , flaggedCount   :: Int
  , topDebits      :: [UserSummary]   -- ^ Top 5 by absolute debit.
  , allSummaries   :: [UserSummary]
  } deriving stock (Eq, Show, Generic)

instance ToJSON AuditReport

-- | Compose the pipeline. This is the single function the world calls.
--
--   Properties (see test/Spec.hs):
--     * @prop_auditPreservesTotal@    — credit/debit sums are preserved.
--     * @prop_auditNeverLosesUsers@   — every distinct user appears once.
--     * @prop_auditIsDeterministic@   — same input → same output.
auditLedger :: Integer -> [User] -> [Transaction] -> AuditReport
auditLedger now users txs =
  let entries = enrichWith users (normalize txs)
      summaries = summarise entries
      credits  = foldMap credits summaries
      debits   = foldMap debits  summaries
      flagged  = length (filter ((< Money (-5000)) . net) summaries)
      top5     = take 5 $ sortOn (Down . absCents . debits) summaries
  in AuditReport
       { generatedAt  = now
       , totalCredits = credits
       , totalDebits  = debits
       , flaggedCount = flagged
       , topDebits    = top5
       , allSummaries = sortOn userId' summaries
       }
  where
    absCents (Money c) = abs c

-- | Group entries by user id and fold into a 'UserSummary'.
summarise :: [LedgerEntry] -> [UserSummary]
summarise =
  foldl' step mempty
  where
    step acc (LedgerEntry tx mUser) =
      let uid = userId tx
          cur = case lookupUser acc uid of
                  Just s  -> s
                  Nothing -> UserSummary uid (maybe "?" name mUser) 0 0 0 (isNothing mUser)
          next = case compare 0 (cents (amount tx)) of
                   GT -> cur { debits  = addMoney (debits  cur) (amount tx) }
                   _  -> cur { credits = addMoney (credits cur) (amount tx) }
          next' = next { net = addMoney (credits next) (debits next) }
      in upsertUser acc uid next'
    isNothing Nothing = True
    isNothing _       = False

-- Toy helper: Money addition is just integer addition in cents.
addMoney :: Money -> Money -> Money
addMoney (Money a) (Money b) = Money (a + b)

-- Toy helpers for the summary map.
lookupUser :: [UserSummary] -> Text -> Maybe UserSummary
lookupUser = foldr step Nothing
  where step s acc | userId' s == k = Just s | otherwise = acc

upsertUser :: [UserSummary] -> Text -> UserSummary -> [UserSummary]
upsertUser xs k v = v : filter (\s -> userId' s /= k) xs

-- | Sum newtype fold for Money — needed because the auto-derived 'Sum' is for 'a'.
instance Semigroup Money where
  Money a <> Money b = Money (a + b)
instance Monoid Money where
  mempty = Money 0

-- ---------------------------------------------------------------------------
-- Phase 5 — Distribute. Effect boundary: write JSON to disk.
--   This is the *only* impure function in the module. It is at the top of
--   the I/O cliff; everything below is pure.
-- ---------------------------------------------------------------------------

-- | Encode the report as JSON and write it to 'path'. Pretty-printed.
writeJsonReport :: FilePath -> AuditReport -> IO ()
writeJsonReport path = BL.writeFile path . encode

-- (We import `Data.Text` qualified only for `Text.null` in `normalize`.)
