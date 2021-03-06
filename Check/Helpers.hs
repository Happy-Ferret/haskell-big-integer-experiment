{-# LANGUAGE CPP, ImplicitParams, MagicHash, UnboxedTuples #-}
module Check.Helpers where

#include "MachDeps.h"

import Control.Monad (unless)
import Data.Bits
import GHC.Base hiding (mapM)
import GHC.Stack (CallStack)
import GHC.Word (Word8)
import Test.Hspec.Expectations (Expectation)
import Test.HUnit (assertFailure)

import qualified System.Random as R

--------------------------------------------------------------------------------
-- Data generators.

mkSmallIntRangeList :: Int -> (Int, Int) -> IO [Int]
mkSmallIntRangeList count (upper, lower) =
    fmap (take count . R.randomRs (upper, lower)) R.newStdGen


mkSmallIntegerList :: Int -> (Int -> a) -> IO [a]
mkSmallIntegerList count constructor =
    fmap (map constructor . take count . R.randoms) R.newStdGen


mkLargeIntegerList :: Int -> (Int, Int) -> IO [(Bool, [Int])]
mkLargeIntegerList count range = do
    signs <- (take count . R.randoms) <$> R.newStdGen
    lengths <- (take count . R.randomRs range) <$> R.newStdGen
    let mkIntList len =
            (take len . R.randomRs (0, 0x7fffffff)) <$> R.newStdGen
    ints <- mapM mkIntList lengths
    pure . take count $ zip signs ints


boxTuple :: (# a, b #) -> (a, b)
boxTuple (# a, b #) = (a, b)

-- The mkInteger functions expect values in range [0, 0x7fffffff].
positive32bits :: [Int] -> [Int]
positive32bits = map (\i -> 0x7fffffff .&. abs i)


shiftCount :: Word8 -> Int#
shiftCount w =
    case fromIntegral w of
        I# i -> i

readInteger :: String -> Integer
readInteger = read


fromString :: String -> [Int]
fromString s =
    decompose $ readInteger s
  where
    decompose x
        | x <= 0 = []
        | otherwise =
            fromIntegral (x .&. 0x7fffffff) : decompose (x `shiftR` 31)

showUT2 :: (Show a, Show b) => (# a, b #) -> String
showUT2 (# a, b #) = "(" ++ show a ++ "," ++ show b ++ ")"


-- A slow naive version of log2Word used to test fast versions.
log2WordSlow :: Word# -> Int#
log2WordSlow =
    loop 0#
  where
    loop :: Int# -> Word# -> Int#
    loop acc# w#
        | isTrue# (word2Int# w# ==# 0#) = acc#
        | otherwise = loop (acc# +# 1#) (uncheckedShiftRL# w# 1#)

bitsPerWord :: Int
bitsPerWord =
#ifndef WORD_SIZE_IN_BITS
    Error: missing WORD_SIZE_IN_BITS #define
#elif  WORD_SIZE_IN_BITS < 64
    32
#else
    64
#endif

-- -----------------------------------------------------------------------------
-- The following heavily inspired by / stolen from Hspec.

#define with_loc(NAME, TYPE) NAME :: (?loc :: CallStack) => TYPE

with_loc(shouldBeNear, (Show a, Ord a, Floating a) => a -> a -> Expectation)
actual `shouldBeNear` expected
    | actual == expected = expectTrue ("expected: " ++ show expected ++ "\n but got: " ++ show actual) (actual == expected)
    | actual == 0 || expected == 0 = expectTrue ("expected: " ++ show expected ++ "\n but got: " ++ show actual) (abs (actual - expected) < 1e-15)
    | otherwise = expectTrue ("expected: " ++ show expected ++ "\n but got: " ++ show actual) (abs (actual - expected) / (abs actual + abs expected) < 1e-15)

with_loc(expectTrue, String -> Bool -> Expectation)
expectTrue msg b = unless b (assertFailure msg)
