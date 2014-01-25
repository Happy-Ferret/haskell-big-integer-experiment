{-# LANGUAGE CPP, MagicHash, ForeignFunctionInterface, NoImplicitPrelude,
             BangPatterns, UnboxedTuples, UnliftedFFITypes #-}
{-# OPTIONS_GHC -fno-warn-orphans #-}


#include "MachDeps.h"

module New3.GHC.Integer.Internals
{-
    ( Integer (..)
    , mkInteger, smallInteger, wordToInteger, integerToWord, integerToInt
#if WORD_SIZE_IN_BITS < 64
    , integerToWord64, word64ToInteger
    , integerToInt64, int64ToInteger
#endif
    , plusInteger, minusInteger, timesInteger, negateInteger
    , eqInteger, neqInteger, absInteger, signumInteger
    , leInteger, gtInteger, ltInteger, geInteger, compareInteger
    , divModInteger, quotRemInteger, quotInteger, remInteger
    , encodeFloatInteger, decodeFloatInteger, floatFromInteger
    , encodeDoubleInteger, decodeDoubleInteger, doubleFromInteger
    -- , gcdInteger, lcmInteger -- XXX
    , andInteger, orInteger, xorInteger, complementInteger
    , shiftLInteger, shiftRInteger
    , hashInteger


    , toList, mkNatural

    ) where
-}
    where

import Prelude hiding (Integer, abs, pi) -- (all, error, otherwise, return, show, succ, (++))

import Control.Monad.Primitive
import Data.Bits

import GHC.Prim
import GHC.Types
import GHC.Tuple ()
#if WORD_SIZE_IN_BITS < 64
import GHC.IntWord64
#endif

import Numeric (showHex) -- TODO: Remove when its working.

import New3.GHC.Integer.Prim
import New3.GHC.Integer.Sign
import New3.GHC.Integer.Type
import New3.GHC.Integer.WordArray

#if !defined(__HADDOCK__)

--------------------------------------------------------------------------------

mkInteger :: Bool   -- non-negative?
          -> [Int]  -- absolute value in 31 bit chunks, least significant first
                    -- ideally these would be Words rather than Ints, but
                    -- we don't have Word available at the moment.
          -> Integer
mkInteger _ [] = smallInteger 0#
mkInteger True [I# i] = smallInteger i
mkInteger False [I# i] = smallInteger (negateInt# i)
mkInteger nonNegative is =
    let abs = f is
    in if nonNegative
        then abs
        else negateInteger abs
  where
    f [] = smallInteger 0#
    f [I# x] = smallInteger x
    f (I# x : xs) = smallInteger x `orInteger` shiftLInteger (f xs) 31#

mkNatural :: [Int] -> Natural
mkNatural ws =
    case mkInteger True ws of
        Positive a -> a
        Negative a -> a
        Zero -> mkSingletonNat 0
        SmallPos x -> mkSingletonNat x
        SmallNeg x -> mkSingletonNat x

{-# NOINLINE smallInteger #-}
smallInteger :: Int# -> Integer
smallInteger i
    | isTrue# (i ==# 0#) = Zero
    | isTrue# (i <# 0#) = SmallNeg (W# (int2Word# (negateInt# i)))
    | otherwise = SmallPos (W# (int2Word# i))

{-# NOINLINE wordToInteger #-}
wordToInteger :: Word# -> Integer
wordToInteger w = SmallPos (W# w)

{-# NOINLINE integerToWord #-}
integerToWord :: Integer -> Word#
integerToWord Zero = 0##
integerToWord (SmallPos (W# w)) = w
integerToWord (SmallNeg (W# w)) = w
integerToWord (Positive (Natural _ arr)) = unboxWord (indexWordArray arr 0)
integerToWord (Negative (Natural _ arr)) = unboxWord (indexWordArray arr 0)

{-# NOINLINE integerToInt #-}
integerToInt :: Integer -> Int#
integerToInt Zero = 0#
integerToInt (SmallPos (W# w)) = word2Int# w
integerToInt (SmallNeg (W# w)) = negateInt# (word2Int# w)
integerToInt (Positive (Natural _ arr)) = firstWordAsInt Pos arr
integerToInt (Negative (Natural _ arr)) = firstWordAsInt Neg arr

firstWordAsInt :: Sign -> WordArray -> Int#
firstWordAsInt s arr =
    let i = word2Int# (unboxWord (indexWordArray arr 0))
    in case s of
        Pos -> i
        Neg -> negateInt# i

#if WORD_SIZE_IN_BITS == 64
-- Nothing
#elif WORD_SIZE_IN_BITS == 32
{-# NOINLINE integerToWord64 #-}
integerToWord64 :: Integer -> Word64#
integerToWord64 = error ("New3/GHC/Integer/Type.hs: line " ++ show (__LINE__ :: Int))

{-# NOINLINE word64ToInteger #-}
word64ToInteger:: Word64# -> Integer
word64ToInteger = error ("New3/GHC/Integer/Type.hs: line " ++ show (__LINE__ :: Int))

{-# NOINLINE integerToInt64 #-}
integerToInt64 :: Integer -> Int64#
integerToInt64 = error ("New3/GHC/Integer/Type.hs: line " ++ show (__LINE__ :: Int))

{-# NOINLINE int64ToInteger #-}
int64ToInteger :: Int64# -> Integer
int64ToInteger = error ("New3/GHC/Integer/Type.hs: line " ++ show (__LINE__ :: Int))
#else
#error WORD_SIZE_IN_BITS not supported
#endif

{-# NOINLINE encodeDoubleInteger #-}
encodeDoubleInteger :: Integer -> Int# -> Double#
encodeDoubleInteger = error ("New3/GHC/Integer/Type.hs: line " ++ show (__LINE__ :: Int))

{-# NOINLINE encodeFloatInteger #-}
encodeFloatInteger :: Integer -> Int# -> Float#
encodeFloatInteger = error ("New3/GHC/Integer/Type.hs: line " ++ show (__LINE__ :: Int))

{-# NOINLINE decodeFloatInteger #-}
decodeFloatInteger :: Float# -> (# Integer, Int# #)
decodeFloatInteger = error ("New3/GHC/Integer/Type.hs: line " ++ show (__LINE__ :: Int))

-- XXX This could be optimised better, by either (word-size dependent)
-- using single 64bit value for the mantissa, or doing the multiplication
-- by just building the Digits directly
{-# NOINLINE decodeDoubleInteger #-}
decodeDoubleInteger :: Double# -> (# Integer, Int# #)
decodeDoubleInteger = error ("New3/GHC/Integer/Type.hs: line " ++ show (__LINE__ :: Int))

{-# NOINLINE doubleFromInteger #-}
doubleFromInteger :: Integer -> Double#
doubleFromInteger = error ("New3/GHC/Integer/Type.hs: line " ++ show (__LINE__ :: Int))

{-# NOINLINE floatFromInteger #-}
floatFromInteger :: Integer -> Float#
floatFromInteger = error ("New3/GHC/Integer/Type.hs: line " ++ show (__LINE__ :: Int))

{-# NOINLINE andInteger #-}
andInteger :: Integer -> Integer -> Integer
andInteger Zero _ = Zero
andInteger _ Zero = Zero

andInteger (SmallPos a) (SmallPos b) = fromSmall Pos (a .&. b)
andInteger (SmallPos a) (SmallNeg b) = fromSmall Pos (a .&. complement (b - 1))
andInteger (SmallNeg a) (SmallPos b) = fromSmall Pos (complement (a - 1) .&. b)
andInteger (SmallNeg a) (SmallNeg b) = fromSmall Neg (1 + ((a - 1) .|. (b - 1)))

andInteger (SmallPos a) (Positive b) = fromSmall Pos (a .&. zerothWordOfNatural b)
andInteger (Positive a) (SmallPos b) = fromSmall Pos (zerothWordOfNatural a .&. b)


andInteger (Positive a) (Positive b) = fromNatural Pos (andNatural a b)

andInteger _ _ = error ("New3/GHC/Integer/Type.hs: line " ++ show (__LINE__ :: Int))

andNatural :: Natural -> Natural -> Natural
andNatural (Natural n1 arr1) (Natural n2 arr2) = andArray (min n1 n2) arr1 arr2

andArray :: Int -> WordArray -> WordArray -> Natural
andArray n arr1 arr2 = unsafeInlinePrim $ do
    !marr <- newWordArray n
    loop1 marr 0
    !narr <- unsafeFreezeWordArray marr
    !nlen <- loop2 narr (n - 1)
    returnNatural nlen narr
  where
    loop1 !marr !i
        | i < n = do
                !x <- indexWordArrayM arr1 i
                !y <- indexWordArrayM arr2 i
                writeWordArray marr i (x .&. y)
                loop1 marr (i + 1)
        | otherwise = return ()
    loop2 !narr !i
        | i < 0 = return 0
        | indexWordArray narr i == 0 = loop2 narr (i - 1)
        | otherwise = return (i + 1)

{-# NOINLINE orInteger #-}
orInteger :: Integer -> Integer -> Integer
orInteger a Zero = a
orInteger Zero b = b

orInteger (SmallPos a) (SmallPos b) = SmallPos (a .|. b)
orInteger (SmallPos a) (SmallNeg b) = SmallNeg (1 + (complement a .&. (b - 1)))
orInteger (SmallNeg a) (SmallPos b) = SmallNeg (1 + ((a - 1) .&. complement b))
orInteger (SmallNeg a) (SmallNeg b) = SmallNeg (1 + ((a - 1) .&. (b - 1)))

orInteger (SmallPos a) (Positive b) = Positive (orNaturalW b a)
orInteger (Positive a) (SmallPos b) = Positive (orNaturalW a b)

orInteger (Positive a) (Positive b) = Positive (orNatural a b)

orInteger _ _ = error ("New3/GHC/Integer/Type.hs: line " ++ show (__LINE__ :: Int))

orNatural :: Natural -> Natural -> Natural
orNatural (Natural n1 arr1) (Natural n2 arr2) = orArray n1 arr1 n2 arr2

orNaturalW :: Natural -> Word -> Natural
orNaturalW !(Natural !n !arr) !w = unsafeInlinePrim $ do
    !marr <- newWordArray n
    copyWordArray marr 1 arr 1 (n - 1)
    !x <- indexWordArrayM arr 0
    writeWordArray marr 0 (w .|. x)
    !narr <- unsafeFreezeWordArray marr
    returnNatural n narr

orArray :: Int -> WordArray -> Int -> WordArray -> Natural
orArray !n1 !arr1 !n2 !arr2
    | n1 < n2 = orArray n2 arr2 n1 arr1
    | otherwise = unsafeInlinePrim $ do
        !marr <- newWordArray n1
        loop1 marr 0
        !narr <- unsafeFreezeWordArray marr
        returnNatural n1 narr
  where
    loop1 !marr !i
        | i < n2 = do
                !x <- indexWordArrayM arr1 i
                !y <- indexWordArrayM arr2 i
                writeWordArray marr i (x .|. y)
                loop1 marr (i + 1)
        | otherwise = loop2 marr i
    loop2 !marr !i
        | i < n1 = do
                -- TODO : Use copyArray here?
                !x <- indexWordArrayM arr1 i
                writeWordArray marr i x
                loop2 marr (i + 1)
        | otherwise = return ()

{-# NOINLINE xorInteger #-}
xorInteger :: Integer -> Integer -> Integer
xorInteger a Zero = a
xorInteger Zero b = b
xorInteger (Positive (Natural n1 arr1)) (Positive (Natural n2 arr2)) = Positive (xorArray n1 arr1 n2 arr2)

xorInteger _ _ = error ("New3/GHC/Integer/Type.hs: line " ++ show (__LINE__ :: Int))


xorArray :: Int -> WordArray -> Int -> WordArray -> Natural
xorArray !n1 !arr1 !n2 !arr2
    | n1 < n2 = xorArray n2 arr2 n1 arr1
    | otherwise = unsafeInlinePrim $ do
        !marr <- newWordArray n1
        loop1 marr 0
        !narr <- unsafeFreezeWordArray marr
        -- TODO : Test this and then optimize.
        finalizeNatural n1 narr
  where
    loop1 !marr !i
        | i < n2 = do
                !x <- indexWordArrayM arr1 i
                !y <- indexWordArrayM arr2 i
                writeWordArray marr i (xor x y)
                loop1 marr (i + 1)
        | otherwise = loop2 marr i
    loop2 !marr !i
        | i < n1 = do
                -- TODO : Use copyArray here?
                !x <- indexWordArrayM arr1 i
                writeWordArray marr i x
                loop2 marr (i + 1)
        | otherwise = return ()

{-# NOINLINE complementInteger #-}
complementInteger :: Integer -> Integer
complementInteger !Zero = SmallNeg 1
complementInteger !(SmallPos !a) = fromSmall Neg (a + 1)
complementInteger !(SmallNeg !a) = fromSmall Pos (a - 1)
complementInteger !(Positive !a) = fromNatural Neg (plusNaturalW a 1)
complementInteger !(Negative !a) = fromNatural Pos (minusNaturalW a 1)


{-# NOINLINE shiftLInteger #-}
shiftLInteger :: Integer -> Int# -> Integer
shiftLInteger !Zero _ = Zero
shiftLInteger !a 0# = a
shiftLInteger !(SmallPos !a) b
    | a == 0 = Zero
    | isTrue# (b >=# WORD_SIZE_IN_BITS#) = fromNatural Pos (shiftLNatural (mkSingletonNat a) (I# b))
    | otherwise =
        let !lo = unsafeShiftL a (I# b)
            !hi = unsafeShiftR a (I# ( WORD_SIZE_IN_BITS# -# b))
        in if hi == 0
            then SmallPos lo
            else Positive (mkPair lo hi)

shiftLInteger !(SmallNeg !a) !b = fromNatural Neg (shiftLNatural (mkSingletonNat a) (I# b))
shiftLInteger !(Positive !a) !b = fromNatural Pos (shiftLNatural a (I# b))
shiftLInteger !(Negative !a) !b = fromNatural Neg (shiftLNatural a (I# b))

shiftLNatural :: Natural -> Int -> Natural
shiftLNatural !nat@(Natural !n !arr) !i
    | i <= 0 = nat
    | i < WORD_SIZE_IN_BITS =
            smallShiftLArray n arr (# i, WORD_SIZE_IN_BITS - i #)
    | otherwise = do
            let (!q, !r) = quotRem i WORD_SIZE_IN_BITS
            if r == 0
                then wordShiftLArray n arr q
                else largeShiftLArray n arr (# q, r, WORD_SIZE_IN_BITS - r #)

smallShiftLArray :: Int -> WordArray -> (# Int, Int #) -> Natural
smallShiftLArray !n !arr (# !si, !sj #) = unsafeInlinePrim $ do
    !marr <- newWordArray (succ n)
    !nlen <- loop marr 0 0
    !narr <- unsafeFreezeWordArray marr
    returnNatural nlen narr
  where
    loop !marr !i !mem
        | i < n =  do
            !x <- indexWordArrayM arr i
            writeWordArray marr i ((unsafeShiftL x si) .|. mem)
            loop marr (i + 1) (unsafeShiftR x sj)
        | mem /= 0 = do
            writeWordArray marr i mem
            return $ i + 1
        | otherwise = return n

-- | TODO : Use copy here? Check benchmark results.
wordShiftLArray :: Int -> WordArray -> Int -> Natural
wordShiftLArray !n !arr !q = unsafeInlinePrim $ do
    !marr <- newWordArray (n + q)
    loop1 marr 0
    !narr <- unsafeFreezeWordArray marr
    returnNatural (n + q) narr
  where
    loop1 !marr !i
        | i < q = do
            writeWordArray marr i 0
            loop1 marr (i + 1)
        | otherwise = loop2 marr 0
    loop2 !marr !i
        | i < n =  do
            !x <- indexWordArrayM arr i
            writeWordArray marr (q + i) x
            loop2 marr (i + 1)
        | otherwise = return ()

largeShiftLArray :: Int -> WordArray-> (# Int, Int, Int #) -> Natural
largeShiftLArray !n !arr (# !q, !si, !sj #) = unsafeInlinePrim $ do
    !marr <- newWordArray (n + q + 1)
    setWordArray marr 0 q 0
    !nlen <- loop1 marr 0 0
    !narr <- unsafeFreezeWordArray marr
    returnNatural nlen narr
  where
    loop1 !marr !i !mem
        | i < n =  do
            !x <- indexWordArrayM arr i
            writeWordArray marr (q + i) ((unsafeShiftL x si) .|. mem)
            loop1 marr (i + 1) (unsafeShiftR x sj)
        | mem /= 0 = do
            writeWordArray marr (q + i) mem
            return (q + i + 1)
        | otherwise = return (q + i)


{-# NOINLINE shiftRInteger #-}
shiftRInteger :: Integer -> Int# -> Integer
shiftRInteger Zero _ = Zero
shiftRInteger !a 0# = a
shiftRInteger !(SmallPos !a) !b
    | isTrue# (b >=# WORD_SIZE_IN_BITS#) = Zero
    | otherwise = fromSmall Pos (shiftRWord a (I# b))
shiftRInteger !(SmallNeg !a) !b
    | isTrue# (b >=# WORD_SIZE_IN_BITS#) = SmallNeg 1
    | otherwise = fromSmall Neg ((shiftRWord (a - 1) (I# b)) + 1)

shiftRInteger !(Positive !a) !b = fromNatural Pos (shiftRNatural a (I# b))
shiftRInteger !(Negative !a) !b =
    let !nat@(Natural !nx _) = shiftRNatural (minusNaturalW a 1) (I# b)
    in if nx == 0
        then SmallNeg 1
        else fromNatural Neg (plusNaturalW nat 1)

shiftRNatural :: Natural -> Int -> Natural
shiftRNatural !(Natural !n !arr) !i
    | i < WORD_SIZE_IN_BITS =
            smallShiftRArray n arr (# i, WORD_SIZE_IN_BITS - i #)
    | otherwise = do
            let (!q, !r) = quotRem i WORD_SIZE_IN_BITS
            if q >= n
                then Natural 0 arr
                else if r == 0
                    then wordShiftRArray n arr q
                    else largeShiftRArray n arr (# q, r, WORD_SIZE_IN_BITS - r #)


smallShiftRArray :: Int -> WordArray -> (# Int, Int #) -> Natural
smallShiftRArray !n !arr (# !si, !sj #) = unsafeInlinePrim $ do
    !marr <- newWordArray n
    loop marr (n - 1) 0
    !narr <- unsafeFreezeWordArray marr
    returnNatural n narr
  where
    loop !marr !i !mem
        | i >= 0 =  do
            !x <- indexWordArrayM arr i
            writeWordArray marr i ((unsafeShiftR x si) .|. mem)
            loop marr (i - 1) (unsafeShiftL x sj)
        | otherwise = return ()

wordShiftRArray :: Int -> WordArray -> Int -> Natural
wordShiftRArray !n !arr !q = unsafeInlinePrim $ do
    !marr <- newWordArray (n - q)
    copyWordArray marr 0 arr q (n - q)
    !narr <- unsafeFreezeWordArray marr
    returnNatural (n - q) narr

largeShiftRArray :: Int -> WordArray-> (# Int, Int, Int #) -> Natural
largeShiftRArray !n !arr (# !q, !si, !sj #) = unsafeInlinePrim $ do
    !marr <- newWordArray (n - q)
    loop marr (n - q - 1) 0
    !narr <- unsafeFreezeWordArray marr
    returnNatural (n - q) narr
  where
    loop !marr !i !mem
        | i >= 0 =  do
            !x <- indexWordArrayM arr (q + i)
            writeWordArray marr i ((unsafeShiftR x si) .|. mem)
            loop marr (i - 1) (unsafeShiftL x sj)
        | otherwise = return ()

{-# NOINLINE negateInteger #-}
negateInteger :: Integer -> Integer
negateInteger !Zero = Zero
negateInteger !(SmallPos !a) = SmallNeg a
negateInteger !(SmallNeg !a) = SmallPos a
negateInteger !(Positive !a) = Negative a
negateInteger !(Negative !a) = Positive a

{-# NOINLINE plusInteger #-}
plusInteger :: Integer -> Integer -> Integer
plusInteger !x !y = case (# x, y #) of
    (# !Zero, !a #) -> a
    (# !a, !Zero #) -> a
    (# !SmallPos !a, !SmallPos !b #) -> safePlusWord Pos a b
    (# !SmallPos !a, !SmallNeg !b #) -> safeMinusWord a b
    (# !SmallNeg !a, !SmallPos !b #) -> safeMinusWord b a
    (# !SmallNeg !a, !SmallNeg !b #) -> safePlusWord Neg a b

    (# !SmallPos !a, !Positive !b #) -> Positive (plusNaturalW b a)
    (# !SmallPos !a, !Negative !b #) -> Negative (minusNaturalW b a)
    (# !SmallNeg !a, !Positive !b #) -> Positive (minusNaturalW b a)
    (# !SmallNeg !a, !Negative !b #) -> Negative (plusNaturalW b a)

    (# !Positive !a, !SmallPos !b #) -> Positive (plusNaturalW a b)
    (# !Positive !a, !SmallNeg !b #) -> Positive (minusNaturalW a b)
    (# !Positive !a, !Positive !b #) -> Positive (plusNatural a b)
    (# !Positive !a, !Negative !b #) -> plusMinusNatural a b

    (# !Negative !a, !SmallPos !b #) -> Negative (minusNaturalW a b)
    (# !Negative !a, !SmallNeg !b #) -> Negative (plusNaturalW a b)
    (# !Negative !a, !Positive !b #) -> plusMinusNatural b a
    (# !Negative !a, !Negative !b #) -> Negative (plusNatural a b)


{-# NOINLINE plusMinusNatural #-}
plusMinusNatural :: Natural -> Natural -> Integer
plusMinusNatural !a !b =
    case compareNatural a b of
        EQ -> Zero
        GT -> fromNatural Pos (minusNatural a b)
        LT -> fromNatural Neg (minusNatural b a)

{-# INLINE safePlusWord #-}
safePlusWord :: Sign -> Word -> Word -> Integer
safePlusWord !sign !w1 !w2 =
    let (# !c, !s #) = plusWord2 w1 w2
    in case (# c == 0, sign #) of
        (# True, Pos #) -> SmallPos s
        (# True, Neg #) -> SmallNeg s
        (# False, Pos #) -> Positive (mkPair s c)
        (# False, Neg #) -> Negative (mkPair s c)

{-# INLINE safeMinusWord #-}
safeMinusWord :: Word -> Word -> Integer
safeMinusWord !a !b =
    case compare a b of
        EQ -> Zero
        GT -> SmallPos (a - b)
        LT -> SmallNeg (b - a)

{-# INLINE plusNaturalW #-}
plusNaturalW :: Natural -> Word -> Natural
plusNaturalW !(Natural !n !arr) !w = unsafeInlinePrim $ do
    !marr <- newWordArray (succ n)
    !x <- indexWordArrayM arr 0
    let (# !cry, !sm #) = plusWord2 x w
    writeWordArray marr 0 sm
    !nlen <- loop1 marr 1 cry
    !narr <- unsafeFreezeWordArray marr
    returnNatural nlen narr
  where
    loop1 !marr !i !carry
        | carry == 0 = loop2 marr i
        | i < n =  do
            !x <- indexWordArrayM arr i
            let (# !cry, !sm #) = plusWord2 x carry
            writeWordArray marr i sm
            loop1 marr (i + 1) cry
        | otherwise = do
            writeWordArray marr i carry
            return $ n + 1
    loop2 !marr !i
        | i < n =  do
            !x <- indexWordArrayM arr i
            writeWordArray marr i x
            loop2 marr (i + 1)
        | otherwise = return i

{-# NOINLINE plusNatural #-}
plusNatural :: Natural -> Natural -> Natural
plusNatural !a@(Natural !n1 !arr1) !b@(Natural !n2 !arr2)
    | n1 < n2 = plusNatural b a
    | otherwise = unsafeInlinePrim $ do
        !marr <- newWordArray (succ n1)
        !nlen <- loop1 marr 0 0
        !narr <- unsafeFreezeWordArray marr
        returnNatural nlen narr
  where
    loop1 !marr !i !carry
        | i < n2 = do
            !x <- indexWordArrayM arr1 i
            !y <- indexWordArrayM arr2 i
            let (# !cry, !sm #) = plusWord2C x y carry
            writeWordArray marr i sm
            loop1 marr (i + 1) cry
        | otherwise = loop2 marr i carry
    loop2 !marr !i !carry
        | carry == 0 = loop3 marr i
        | i < n1 = do
            !x <- indexWordArrayM arr1 i
            let (# !cry, !sm #) = plusWord2 x carry
            writeWordArray marr i sm
            loop2 marr (i + 1) cry
        | otherwise = do
            writeWordArray marr i carry
            return (i + 1)
    loop3 !marr !i
        | i < n1 = do
            !x <- indexWordArrayM arr1 i
            writeWordArray marr i x
            loop3 marr (i + 1)
        | otherwise = return i


{-# INLINE minusInteger #-}
minusInteger :: Integer -> Integer -> Integer
minusInteger !x !y = case (# x, y #) of
    (# !a, !Zero #) -> a
    (# !Zero, !a #) -> negateInteger a
    (# !SmallPos !a, !SmallPos !b #) -> safeMinusWord a b
    (# !SmallPos !a, !SmallNeg !b #) -> safePlusWord Pos a b
    (# !SmallNeg !a, !SmallPos !b #) -> safePlusWord Neg a b
    (# !SmallNeg !a, !SmallNeg !b #) -> safeMinusWord b a

    (# !SmallPos !a, !Positive !b #) -> Negative (minusNaturalW b a)
    (# !SmallPos !a, !Negative !b #) -> Positive (plusNaturalW b a)

    (# !SmallNeg !a, !Positive !b #) -> Negative (plusNaturalW b a)
    (# !SmallNeg !a, !Negative !b #) -> Positive (minusNaturalW b a)

    (# !Positive !a, !SmallPos !b #) -> Positive (minusNaturalW a b)
    (# !Positive !a, !SmallNeg !b #) -> Positive (plusNaturalW a b)
    (# !Positive !a, !Positive !b #) -> plusMinusNatural a b
    (# !Positive !a, !Negative !b #) -> Positive (plusNatural a b)

    (# !Negative !a, !SmallPos !b #) -> Negative (plusNaturalW a b)
    (# !Negative !a, !SmallNeg !b #) -> Negative (minusNaturalW a b)
    (# !Negative !a, !Positive !b #) -> Negative (plusNatural a b)
    (# !Negative !a, !Negative !b #) -> plusMinusNatural b a

{-# INLINE minusNaturalW #-}
minusNaturalW :: Natural -> Word -> Natural
minusNaturalW !(Natural !n !arr) !w = unsafeInlinePrim $ do
    !marr <- newWordArray (succ n)
    !x <- indexWordArrayM arr 0
    let (# !c, !d #) = minusWord2 x w
    writeWordArray marr 0 d
    !nlen <- loop1 marr 1 c
    !narr <- unsafeFreezeWordArray marr
    returnNatural nlen narr
  where
    loop1 !marr !i !carry
        | carry == 0 = loop2 marr i
        | i < n =  do
            !x <- indexWordArrayM arr i
            let (# !c, !d #) = minusWord2 x carry
            writeWordArray marr i d
            loop1 marr (i + 1) c
        | otherwise = do
            writeWordArray marr i carry
            return $ n + 1
    loop2 !marr !i
        | i < n =  do
            !x <- indexWordArrayM arr i
            writeWordArray marr i x
            loop2 marr (i + 1)
        | otherwise = return n


{-# INLINE minusNatural #-}
minusNatural :: Natural -> Natural -> Natural
minusNatural !a@(Natural !n1 !arr1) !b@(Natural !n2 !arr2)
    | n1 < n2 = plusNatural b a
    | otherwise = unsafeInlinePrim $ do
        !marr <- newWordArray (succ n1)
        !nlen <- loop1 marr 0 0
        !narr <- unsafeFreezeWordArray marr
        finalizeNatural nlen narr
  where
    loop1 !marr !i !carry
        | i < n2 = do
            !x <- indexWordArrayM arr1 i
            !y <- indexWordArrayM arr2 i
            let (# !c, !d #) = minusWord2C x y carry
            writeWordArray marr i d
            loop1 marr (i + 1) c
        | otherwise = loop2 marr i carry
    loop2 !marr !i !carry
        | carry == 0 = loop3 marr i
        | i < n1 = do
            !x <- indexWordArrayM arr1 i
            let (# !c, !d #) = minusWord2 x carry
            writeWordArray marr i d
            loop2 marr (i + 1) c
        | otherwise = do
            writeWordArray marr i carry
            return (i + 1)
    loop3 !marr !i
        | i < n1 = do
            !x <- indexWordArrayM arr1 i
            writeWordArray marr i x
            loop3 marr (i + 1)
        | otherwise = return i


{-# NOINLINE timesInteger #-}
timesInteger :: Integer -> Integer -> Integer
timesInteger !x !y = case (# x, y #) of
    (# Zero, _ #) -> Zero
    (# _, Zero #) -> Zero

    (# SmallPos a, SmallPos b #) -> safeTimesWord Pos a b
    (# SmallPos a, SmallNeg b #) -> safeTimesWord Neg a b
    (# SmallNeg a, SmallPos b #) -> safeTimesWord Neg a b
    (# SmallNeg a, SmallNeg b #) -> safeTimesWord Pos a b

    (# SmallPos a, Positive b #) -> Positive (timesNaturalW b a)
    (# SmallPos a, Negative b #) -> Negative (timesNaturalW b a)
    (# SmallNeg a, Positive b #) -> Negative (timesNaturalW b a)
    (# SmallNeg a, Negative b #) -> Positive (timesNaturalW b a)

    (# Positive a, SmallPos b #) -> Positive (timesNaturalW a b)
    (# Positive a, SmallNeg b #) -> Negative (timesNaturalW a b)
    (# Positive a, Positive b #) -> Positive (timesNatural a b)
    (# Positive a, Negative b #) -> Negative (timesNatural a b)

    (# Negative a, SmallPos b #) -> Negative (timesNaturalW a b)
    (# Negative a, SmallNeg b #) -> Positive (timesNaturalW a b)
    (# Negative a, Positive b #) -> Negative (timesNatural a b)
    (# Negative a, Negative b #) -> Positive (timesNatural a b)


{-# INLINE safeTimesWord #-}
safeTimesWord :: Sign -> Word -> Word -> Integer
safeTimesWord !sign !w1 !w2 =
    let (# !ovf, !prod #) = timesWord2 w1 w2
    in case (# ovf == 0, sign #) of
        (# False, Pos #) -> Positive (mkPair prod ovf)
        (# False, Neg #) -> Negative (mkPair prod ovf)
        (# True, Pos #) -> SmallPos prod
        (# True, Neg #) -> SmallNeg prod


{-# NOINLINE timesNaturalW #-}
timesNaturalW :: Natural -> Word -> Natural
timesNaturalW !(Natural !n !arr) !w = unsafeInlinePrim $ do
    !marr <- newWordArrayCleared (succ n)
    !nlen <- loop marr 0 0
    !narr <- unsafeFreezeWordArray marr
    returnNatural nlen narr
  where
    loop !marr !i !carry
        | i < n = do
            !x <- indexWordArrayM arr i
            let (# !c, !p #) = timesWord2C x w carry
            writeWordArray marr i p
            loop marr (i + 1) c
        | carry /= 0 = do
            writeWordArray marr i carry
            return (i + 1)
        | otherwise = return i

{-# NOINLINE timesNatural #-}
timesNatural :: Natural -> Natural -> Natural
timesNatural !a@(Natural !n1 !arr1) !b@(Natural !n2 !arr2)
    | n1 < n2 = timesNatural b a
    | otherwise = unsafeInlinePrim $ do
        !psum <- newPlaceholderWordArray
        outerLoop 0 psum 0
  where
    outerLoop !psumLen !psum !s2
        | s2 < n2 = do
            !w <- indexWordArrayM arr2 s2
            if w == 0
                then outerLoop psumLen psum (succ s2)
                else do
                    let !newPsumLen = succ (max psumLen (n1 + succ s2))
                    !marr <- cloneWordArrayExtend psumLen psum newPsumLen
                    !possLen <- innerLoop1 marr psumLen psum 0 s2 w 0
                    !narr <- unsafeFreezeWordArray marr
                    outerLoop possLen narr (succ s2)
        | otherwise =
            returnNatural psumLen psum

    innerLoop1 !marr !pn !psum !s1 !s2 !hw !carry
        | s1 + s2 < pn = do
            !ps <- indexWordArrayM psum (s1 + s2)
            !x <- indexWordArrayM arr1 s1
            let (# !hc, !hp #) = timesWord2CC x hw carry ps
            writeWordArray marr (s1 + s2) hp
            innerLoop1 marr pn psum (s1 + 1) s2 hw hc
        | otherwise = innerLoop2 marr pn psum s1 s2 hw carry

    innerLoop2 !marr !pn !psum !s1 !s2 !hw !carry
        | s1 < n1 = do
            !x <- indexWordArrayM arr1 s1
            let (# !hc, !hp #) = timesWord2C x hw carry
            writeWordArray marr (s1 + s2) hp
            innerLoop2 marr pn psum (s1 + 1) s2 hw hc
        | carry /= 0 = do
            writeWordArray marr (s1 + s2) carry
            return (s1 + s2 + 1)
        | otherwise = return (s1 + s2)



{-# NOINLINE divModInteger #-}
divModInteger :: Integer -> Integer -> (# Integer, Integer #)
divModInteger _ _ = error ("New3/GHC/Integer/Type.hs: line " ++ show (__LINE__ :: Int))

{-# NOINLINE quotRemInteger #-}
quotRemInteger :: Integer -> Integer -> (# Integer, Integer #)
quotRemInteger _ _ = error ("New3/GHC/Integer/Type.hs: line " ++ show (__LINE__ :: Int))

{-# NOINLINE quotInteger #-}
quotInteger :: Integer -> Integer -> Integer
quotInteger a b =
    let (# q, _ #) = quotRemInteger a b
    in q

{-# NOINLINE remInteger #-}
remInteger :: Integer -> Integer -> Integer
remInteger = error ("New3/GHC/Integer/Type.hs: line " ++ show (__LINE__ :: Int))

{-# NOINLINE compareInteger #-}
compareInteger :: Integer -> Integer -> Ordering
compareInteger = error ("New3/GHC/Integer/Type.hs: line " ++ show (__LINE__ :: Int))

{-# NOINLINE eqInteger #-}
eqInteger :: Integer -> Integer -> Bool
eqInteger !Zero !Zero = True
eqInteger !(SmallPos !a) !(SmallPos !b) = a == b
eqInteger !(SmallNeg !a) !(SmallNeg !b) = b == a
eqInteger !(Positive !a) !(Positive !b) = eqNatural a b
eqInteger !(Negative !a) !(Negative !b) = eqNatural a b

eqInteger !(SmallPos _) !Zero = False
eqInteger !(SmallPos _) !(SmallNeg _) = False
eqInteger !(SmallPos _) !(Positive _) = False
eqInteger !(SmallPos _) !(Negative _) = False

eqInteger !(Positive _) !Zero = False
eqInteger !(Positive _) !(SmallPos _) = False
eqInteger !(Positive _) !(SmallNeg _) = False
eqInteger !(Positive _) !(Negative _) = False

eqInteger !Zero _ = False
eqInteger !(SmallNeg _) _ = False
eqInteger !(Negative _) _ = False


eqNatural :: Natural -> Natural -> Bool
eqNatural !(Natural !n1 !arr1) !(Natural !n2 !arr2)
    | n1 /= n2 = False
    | otherwise =
        let eqArray !idx
                | idx < 0 = True
                | indexWordArray arr1 idx /= indexWordArray arr2 idx = False
                | otherwise = eqArray (idx - 1)
        in eqArray (n1 - 1)

compareNatural :: Natural -> Natural -> Ordering
compareNatural !(Natural !n1 !arr1) !(Natural !n2 !arr2)
    | n1 < n2 = LT
    | n1 > n2 = GT
    | otherwise =
        let cmpArray !idx
                | idx < 0 = EQ
                | otherwise =
                    case compare (indexWordArray arr1 idx) (indexWordArray arr2 idx) of
                        EQ -> cmpArray (idx - 1)
                        cmp -> cmp
        in cmpArray (n1 - 1)


{-# NOINLINE neqInteger #-}
neqInteger :: Integer -> Integer -> Bool
neqInteger !a !b = not (eqInteger a b)

instance  Eq Integer  where
    (==) = eqInteger
    (/=) = neqInteger

{-# NOINLINE ltInteger #-}
ltInteger :: Integer -> Integer -> Bool
ltInteger !Zero !Zero = False
ltInteger !(SmallPos _) !Zero = False
ltInteger !(SmallNeg _) !Zero = True

ltInteger !(SmallPos !a) !(SmallPos !b) = a < b
ltInteger !(SmallNeg !a) !(SmallNeg !b) = b < a
ltInteger !(SmallPos _) !(SmallNeg _) = False
ltInteger !(SmallNeg _) !(SmallPos _) = True

ltInteger !(SmallPos _) !(Positive _) = True
ltInteger !(SmallPos _) !(Negative _) = False
ltInteger !(SmallNeg _) !(Positive _) = True
ltInteger !(SmallNeg _) !(Negative _) = False

ltInteger !(Positive _) !Zero = False
ltInteger !(Positive _) !(SmallPos _) = False
ltInteger !(Positive _) !(SmallNeg _) = False
ltInteger !(Positive _) !(Negative _) = False

ltInteger !(Negative _) !Zero = True
ltInteger !(Negative _) !(SmallPos _) = True
ltInteger !(Negative _) !(SmallNeg _) = True
ltInteger !(Negative _) !(Positive _) = True

ltInteger !(Positive !a) !(Positive !b) = ltNatural a b
ltInteger !(Negative !a) !(Negative !b) = ltNatural b a

ltInteger !Zero !(SmallPos _) = True
ltInteger !Zero !(Positive _) = True
ltInteger !Zero !(SmallNeg _) = False
ltInteger !Zero !(Negative _) = False

ltNatural :: Natural -> Natural -> Bool
ltNatural !(Natural !n1 !arr1) !(Natural !n2 !arr2)
    | n1 < n2 = True
    | n1 > n2 = False
    | otherwise =
        let check 0 = indexWordArray arr1 0 < indexWordArray arr2 0
            check i =
                if indexWordArray arr1 i == indexWordArray arr2 i
                    then check (i - 1)
                    else indexWordArray arr1 i < indexWordArray arr2 i
        in check (n1 - 1)


{-# NOINLINE gtInteger #-}
gtInteger :: Integer -> Integer -> Bool
gtInteger !Zero !Zero = False
gtInteger !(SmallPos _) !Zero = True
gtInteger !(SmallNeg _) !Zero = False

gtInteger !(SmallPos !a) !(SmallPos !b) = a > b
gtInteger !(SmallNeg !a) !(SmallNeg !b) = a < b
gtInteger !(SmallPos _) !(SmallNeg _) = True
gtInteger !(SmallNeg _) !(SmallPos _) = False

gtInteger !(SmallPos _) !(Positive _) = False
gtInteger !(SmallPos _) !(Negative _) = True
gtInteger !(SmallNeg _) !(Positive _) = False
gtInteger !(SmallNeg _) !(Negative _) = True

gtInteger !(Positive _) !Zero = True
gtInteger !(Positive _) !(SmallPos _) = True
gtInteger !(Positive _) !(SmallNeg _) = True
gtInteger !(Positive _) !(Negative _) = True

gtInteger !(Negative _) !Zero = False
gtInteger !(Negative _) !(SmallPos _) = False
gtInteger !(Negative _) !(SmallNeg _) = False
gtInteger !(Negative _) !(Positive _) = False

gtInteger !(Positive !a) !(Positive !b) = gtNatural a b
gtInteger !(Negative !a) !(Negative !b) = gtNatural b a

gtInteger !Zero !(SmallPos _) = False
gtInteger !Zero !(Positive _) = False
gtInteger !Zero !(SmallNeg _) = True
gtInteger !Zero !(Negative _) = True


gtNatural :: Natural -> Natural -> Bool
gtNatural !(Natural !n1 !arr1) !(Natural !n2 !arr2)
    | n1 > n2 = True
    | n1 < n2 = False
    | otherwise =
            let check 0 = indexWordArray arr1 0 > indexWordArray arr2 0
                check i =
                    if indexWordArray arr1 i == indexWordArray arr2 i
                        then check (i - 1)
                        else indexWordArray arr1 i > indexWordArray arr2 i
            in check (n1 - 1)

leInteger :: Integer -> Integer -> Bool
leInteger !a !b = not (gtInteger a b)

geInteger :: Integer -> Integer -> Bool
geInteger !a !b = not (ltInteger a b)

instance Ord Integer where
    (<=) = leInteger
    (>)  = gtInteger
    (<)  = ltInteger
    (>=) = geInteger
    compare = compareInteger

{-# NOINLINE absInteger #-}
absInteger :: Integer -> Integer
absInteger !Zero = Zero
absInteger !a@(SmallPos _) = a
absInteger !(SmallNeg !a) = SmallPos a
absInteger !a@(Positive _) = a
absInteger !(Negative !a) = Positive a

{-# NOINLINE signumInteger #-}
signumInteger :: Integer -> Integer
signumInteger = error ("New3/GHC/Integer/Type.hs: line " ++ show (__LINE__ :: Int))

{-# NOINLINE hashInteger #-}
hashInteger :: Integer -> Int#
hashInteger = integerToInt

--------------------------------------------------------------------------------
-- Helpers (not part of the API).


{-# INLINE unboxWord #-}
unboxWord :: Word -> Word#
unboxWord !(W# !w) = w


{-# INLINE fromSmall #-}
fromSmall :: Sign -> Word -> Integer
fromSmall !s !w
    | w == 0 = Zero
    | s == Pos = SmallPos w
    | otherwise = SmallNeg w

{-# INLINE fromNatural #-}
fromNatural :: Sign -> Natural -> Integer
fromNatural !s !nat@(Natural n arr)
    | n == 0 = Zero
    | n == 1 && indexWordArray arr 0 == 0 = Zero -- TODO: See if this can be removed.
    | s == Pos = Positive nat
    | otherwise = Negative nat

{-# INLINE zerothWordOfNatural #-}
zerothWordOfNatural :: Natural -> Word
zerothWordOfNatural !(Natural _ arr) = indexWordArray arr 0

mkPair :: Word -> Word -> Natural
mkPair !sm !carry = unsafeInlinePrim mkNatPair
  where
    mkNatPair :: IO Natural
    mkNatPair = do
        !marr <- newWordArray 2
        writeWordArray marr 0 sm
        writeWordArray marr 1 carry
        !narr <- unsafeFreezeWordArray marr
        return $ Natural 2 narr

mkSingletonNat :: Word -> Natural
mkSingletonNat !x = unsafeInlinePrim mkNat
  where
    mkNat :: IO Natural
    mkNat = do
        !marr <- newWordArray 1
        writeWordArray marr 0 x
        !narr <- unsafeFreezeWordArray marr
        return $ Natural 1 narr


finalizeNatural :: Int -> WordArray -> IO Natural
finalizeNatural 0 !arr = return (Natural 0 arr)
finalizeNatural !nin !arr = do
    let !len = nonZeroLen nin arr
    !x <- indexWordArrayM arr 0
    return $
        if len < 0 || (len == 1 && x == 0)
            then Natural 0 arr
            else Natural len arr

nonZeroLen :: Int -> WordArray -> Int
nonZeroLen !len !arr
    | len <= 1 = 0
    | otherwise =
        let trim i
                | i < 1 = 0
                | indexWordArray arr i == 0 = trim (i - 1)
                | otherwise = i + 1
        in trim (len - 1)


{-# INLINE returnNatural #-}
returnNatural :: Int -> WordArray -> IO Natural
returnNatural !0 !arr = return (Natural 0 arr)
returnNatural !n !arr = return (Natural n arr)


oneInteger, minusOneInteger :: Integer
oneInteger = SmallPos 1
minusOneInteger = SmallNeg 1

{-

twoToTheThirtytwoInteger :: Integer
twoToTheThirtytwoInteger = error ("New3/GHC/Integer/Type.hs: line " ++ show (__LINE__ :: Int))
-}


toList :: Integer -> [Word]
toList ii =
    case ii of
        Zero -> [0]
        SmallPos w -> [w]
        SmallNeg w -> [w]
        Positive nat -> natList nat
        Negative nat -> natList nat
  where
    natList (Natural n arr) = unpackArray 0
        where
            unpackArray i
                | i < n = do
                    let xs = unpackArray (i + 1)
                        x = indexWordArray arr i
                    x : xs
                | otherwise = []

arrayShow :: Int -> WordArray -> String
arrayShow !len !arr =
    let hexify w =
            let x = showHex w ""
            in replicate (16 - length x) '0' ++ x
        digits = dropWhile (== '0') . concatMap hexify . reverse $ unpackArray 0
    in if null digits then "0x0" else "0x" ++ digits
  where
    unpackArray i
        | i < len = do
                let xs = unpackArray (i + 1)
                    x = indexWordArray arr i
                x : xs
        | otherwise = []


hexShowW :: Word -> String
hexShowW w = "0x" ++ showHex w ""

signShow :: Sign -> String
signShow Pos = "Pos"
signShow Neg = "Neg"

absInt :: Int -> Int
absInt x = if x < 0 then -x else x

debugPutStrLn :: Int -> String -> IO ()
debugPutStrLn line s = putStrLn $ show line ++ " : " ++ s
-- debugPutStrLn _ = return ()

isSmall :: Integer -> Bool
isSmall Zero = True
isSmall (SmallPos _) = True
isSmall (SmallNeg _) = True
isSmall _ = False

assertNatural :: Int -> Natural -> IO ()
assertNatural linenum (Natural n arr) =
    if n <= 0
        then error $ "Bad natural (" ++ show linenum ++ ") " ++ show n ++ " " ++ arrayShow n arr
        else return ()

traceNatural :: Int -> Natural -> Natural
traceNatural linenum nat@(Natural n arr) =
    if n <= 0
        then error $ "Bad natural (" ++ show linenum ++ ") " ++ show n ++ " " ++ arrayShow n arr
        else nat

errorLine :: Int -> String -> a
errorLine linenum s = error $ "Line " ++ show linenum ++ ": " ++ s

isMinimal :: Integer -> Bool
isMinimal i =
    case i of
        Zero -> True
        SmallPos a -> a /= 0
        SmallNeg a -> a /= 0
        Positive a -> isMinimalNatural a
        Negative a -> isMinimalNatural a
  where
    isMinimalNatural (Natural 0 _) = False
    isMinimalNatural (Natural n arr) = indexWordArray arr (n - 1) /= 0

#endif