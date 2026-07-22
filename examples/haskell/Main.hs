{-# LANGUAGE OverloadedStrings #-}
-- |
-- Driver: reads the fake data, runs the pure pipeline, writes the report.
--
--   cabal run audit-cli -- data/transactions.csv data/users.json reports/audit.json
module Main (main) where

import           Audit
import           Data.Aeson         (eitherDecodeFileStrict', encode)
import qualified Data.ByteString.Lazy as BL
import qualified Data.Csv           as Csv
import qualified Data.Vector        as V
import           System.Environment (getArgs)
import           Data.Time.Clock.POSIX (getPOSIXTime)
import           Data.Maybe         (fromMaybe)
import qualified Data.Text          as T
import qualified Data.Text.Encoding as TE

main :: IO ()
main = do
  args <- getArgs
  case args of
    [inFile, userFile, outFile] -> do
      users  <- loadUsers   userFile
      txs    <- loadCsvTxs  inFile
      now    <- round <$> getPOSIXTime
      let report = auditLedger now users txs
      BL.writeFile outFile (encode report)
      putStrLn $ "Wrote " <> outFile
      putStrLn $ "  totalCredits = " <> show (totalCredits report)
      putStrLn $ "  totalDebits  = " <> show (totalDebits  report)
      putStrLn $ "  flaggedCount = " <> show (flaggedCount report)
    _ -> putStrLn "usage: audit-cli <transactions.csv> <users.json> <out.json>"

loadUsers :: FilePath -> IO [User]
loadUsers path = do
  res <- eitherDecodeFileStrict' path
  case res of
    Right xs -> pure xs
    Left  e  -> error $ "failed to parse users: " <> e

-- Minimal CSV reader. The real production code would use `cassava` or
-- a streaming parser; this is enough to run the demo.
loadCsvTxs :: FilePath -> IO [Transaction]
loadCsvTxs path = do
  bs <- BL.readFile path
  case Csv.decode Csv.HasHeader bs of
    Left  e  -> error $ "csv parse error: " <> e
    Right v  -> pure $ mapMaybe fromRow (V.toList v)

fromRow :: Csv.Record -> Maybe Transaction
fromRow r = do
  txId'    <- at 0 r
  actorId' <- at 1 r
  userId'  <- at 2 r
  amt      <- readMaybe =<< at 3 r
  cur      <- parseCur =<< at 4 r
  ts'      <- readMaybe =<< at 5 r
  memo'    <- at 6 r
  pure Transaction
    { txId      = txId'
    , actorId   = actorId'
    , userId    = userId'
    , amount    = Money amt
    , currency  = cur
    , ts        = ts'
    , memo      = memo'
    }
  where
    at i r = case drop i r of
      (x:_) -> Just (TE.decodeUtf8 x)
      _     -> Nothing
    parseCur "EUR" = Just EUR
    parseCur "USD" = Just USD
    parseCur "GBP" = Just GBP
    parseCur "JPY" = Just JPY
    parseCur _     = Nothing

readMaybe :: Read a => String -> Maybe a
readMaybe s = case reads s of
  [(x, "")] -> Just x
  _         -> Nothing

mapMaybe :: (a -> Maybe b) -> [a] -> [b]
mapMaybe f = foldr (\x acc -> case f x of Just y -> y : acc; Nothing -> acc) []
