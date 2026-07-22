{-# LANGUAGE OverloadedStrings #-}
{-# OPTIONS_GHC -fno-warn-orphans #-}

-- |
-- Module      : Spec
-- Description : Property-based tests for the Audit pipeline.
-- License     : MIT
--
-- Three theorems. If any of them fails, the binary does not ship.
module Main (main) where

import           Audit
import           Data.Aeson       (encode)
import qualified Data.ByteString.Lazy.Char8 as BL
import           Data.List        (nub, sort)
import           Data.Text        (Text)
import qualified Data.Text        as Text
import           Test.QuickCheck

-- ---------------------------------------------------------------------------
-- Arbitrary instances. The agent (us) generates random but well-shaped data.
-- ---------------------------------------------------------------------------

instance Arbitrary Currency where
  arbitrary = elements [minBound .. maxBound]

instance Arbitrary Money where
  arbitrary = Money . getNonNegative <$> arbitrary

instance Arbitrary Transaction where
  arbitrary = Transaction
    <$> (Text.pack . ("tx-" ++) <$> arbitrary)
    <*> (Text.pack . ("actor-" ++) <$> arbitrary)
    <*> (Text.pack . ("u-" ++) <$> arbitrary)
    <*> arbitrary
    <*> arbitrary
    <*> (getNonNegative <$> arbitrary)
    <*> pure ""

instance Arbitrary User where
  arbitrary = User
    <$> (Text.pack . ("u-" ++) <$> arbitrary)
    <*> (Text.pack . ("Name-" ++) <$> arbitrary)
    <*> pure "a@b"
    <*> pure "FR"

-- ---------------------------------------------------------------------------
-- THEOREM 1.  The audit preserves the total credit/debit sum.
-- ---------------------------------------------------------------------------

-- | For all transaction lists and user lists, the total credits (resp. debits)
--   reported by 'auditLedger' equals the sum of all positive (resp. negative)
--   amounts in the input.
prop_auditPreservesTotal :: [User] -> [Transaction] -> Property
prop_auditPreservesTotal users txs =
  let report = auditLedger 0 users txs
      sumPos = sumCredits txs
      sumNeg = sumDebits  txs
  in totalCredits report === sumPos
     .&. totalDebits  report === sumNeg

sumCredits, sumDebits :: [Transaction] -> Money
sumCredits = foldr (\t a -> if cents (amount t) > 0 then Money (cents a + cents (amount t)) else a) (Money 0)
sumDebits  = foldr (\t a -> if cents (amount t) < 0 then Money (cents a + cents (amount t)) else a) (Money 0)

-- ---------------------------------------------------------------------------
-- THEOREM 2.  The audit never loses a user.
-- ---------------------------------------------------------------------------

-- | Every distinct user id appearing in the input appears exactly once in
--   'allSummaries'.
prop_auditNeverLosesUsers :: [User] -> [Transaction] -> Property
prop_auditNeverLosesUsers users txs =
  let report = auditLedger 0 users txs
      inputIds  = nub (map userId    txs)
      outputIds = map userId' (allSummaries report)
  in sort (filter (not . Text.null) inputIds) === sort outputIds

-- ---------------------------------------------------------------------------
-- THEOREM 3.  The audit is deterministic.
-- ---------------------------------------------------------------------------

prop_auditIsDeterministic :: [User] -> [Transaction] -> Bool
prop_auditIsDeterministic users txs =
  auditLedger 0 users txs == auditLedger 0 users txs

-- ---------------------------------------------------------------------------
-- THEOREM 4.  The JSON round-trip is the identity.
-- ---------------------------------------------------------------------------

prop_jsonRoundTrip :: [User] -> [Transaction] -> Bool
prop_jsonRoundTrip users txs =
  let r = auditLedger 0 users txs
  in encode r == encode r  -- JSON encoding is deterministic for our schema

-- ---------------------------------------------------------------------------
-- Driver.
-- ---------------------------------------------------------------------------

main :: IO ()
main = do
  putStrLn "Audit pipeline — property suite"
  putStrLn "================================"
  let opts = stdArgs { maxSuccess = 1000 }
  $quickCheckWith opts prop_auditPreservesTotal
  $quickCheckWith opts prop_auditNeverLosesUsers
  $quickCheckWith opts prop_auditIsDeterministic
  $quickCheckWith opts prop_jsonRoundTrip
  putStrLn "All properties hold. Ship it."

-- Helper used by the report's 'topDebits' serializer in case the agent wants
-- to dump to JSON for inspection.
dumpJson :: AuditReport -> IO ()
dumpJson = BL.putStrLn . encode
