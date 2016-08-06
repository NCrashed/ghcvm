{-# LANGUAGE EmptyDataDecls, MagicHash, NoImplicitPrelude #-}
module GHC.Integer.Type where

import GHC.Prim

data {-# CLASS "java.math.BigInteger" #-} Integer#

-- TODO: Change J#
data Integer
  = S# Int#
  | J# JChar#

-- TODO: Incomplete
mkInteger :: Bool -> [Int] -> Integer
mkInteger nonNegative is = S# 0#

{-# NOINLINE smallInteger #-}
smallInteger :: Int# -> Integer
smallInteger = S#