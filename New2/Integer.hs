{-# LANGUAGE BangPatterns, NoImplicitPrelude, MagicHash #-}
{-# OPTIONS_GHC -fno-warn-orphans #-}

module New2.Integer
    ( module New2.GHC.Integer
    , hexShow
    , readInteger
    ) where

import Prelude hiding (Integer)
import Data.Char (ord)
import Data.List (foldl')
import GHC.Types
import Numeric

import Common.GHC.Integer.Prim
import Common.GHC.Integer.WordArray
import New2.GHC.Integer
import New2.GHC.Integer.Type


instance Num Integer where
    (+) = plusInteger
    (-) = minusInteger
    (*) = timesInteger
    abs = absInteger
    signum = signumInteger
    fromInteger = readInteger . show


instance Show Integer where
    show = hexShow


hexShow :: Integer -> String
hexShow (Positive n) = hexShowNatural '+' n
hexShow (Negative n) = hexShowNatural '-' n

hexShowNatural :: Char -> Natural -> String
hexShowNatural _ (Small 0) = "0x0"
hexShowNatural sign (Small a) = sign : "0x" ++ showHex a ""
hexShowNatural sign (Large n arr) =
    if n == 1 && indexWordArray arr 0 == 0
        then "0x0"
        else sign : arrayShow n arr

readInteger :: String -> Integer
readInteger [] = 0
readInteger ('-':xs) = -1 * readInteger xs
readInteger ('+':xs) = readInteger xs
readInteger ('0':'x':xs) = readIntegerHex xs
readInteger s =
    foldl' (\acc c -> acc * (smallInteger 10#) + readChar c) (smallInteger 0#) s
  where
    readChar :: Char -> Integer
    readChar c =
        let !(I# i) = ord c - 48
        in smallInteger i


readIntegerHex :: String -> Integer
readIntegerHex s =
    foldl' (\acc c -> acc * (smallInteger 16#) + readChar (ord c)) (smallInteger 0#) s
  where
    readChar :: Int -> Integer
    readChar c
        | c >= 0x30 && c <= 0x39 = smallInteger (unboxInt (c - 0x30))
        | c >= 0x41 && c <= 0x46 = smallInteger (unboxInt (10 + c - 0x41))
        | otherwise = smallInteger (unboxInt (10 + c - 0x61))
