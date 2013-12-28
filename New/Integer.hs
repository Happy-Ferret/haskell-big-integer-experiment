{-# LANGUAGE NoImplicitPrelude, MagicHash #-}
{-# OPTIONS_GHC -fno-warn-orphans #-}

-- *All* of this code was ripped from the GHC sources.
-- We need this because the Integer we are compiling and testing is *not* the
-- same as the Integer GHC already knows about.

module New.Integer
    ( module New.GHC.Integer
    ) where

import Prelude hiding (Integer)
import Numeric

import New.GHC.Integer
import New.GHC.Integer.Array
import New.GHC.Integer.Sign
import New.GHC.Integer.Type


instance Num Integer where
    (+) = plusInteger
    (-) = minusInteger
    (*) = minusInteger
    abs = absInteger
    signum = signumInteger
    fromInteger = error "New.Integer: fromInteger"


instance Show Integer where
    show = hexShow


hexShow :: Integer -> String
hexShow (Small _ 0) = "0x0"
hexShow (Small s a) =
    let sign = if s == Neg then '-' else '+'
    in sign : "0x" ++ showHex a ""

hexShow (Large s n arr)
    | n == 1 && indexWordArray arr 0 == 0 = "0x0"
    | otherwise =
        let sign = if s == Neg then '-' else '+'
        in sign : arrayShow n arr


