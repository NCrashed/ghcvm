module GHCVM.Main.DynFlags where

import GHCVM.Utils.Platform

data DynFlags

targetPlatform       :: DynFlags -> Platform
pprUserLength        :: DynFlags -> Int
pprCols              :: DynFlags -> Int
unsafeGlobalDynFlags :: DynFlags
useUnicode     :: DynFlags -> Bool
useUnicodeSyntax     :: DynFlags -> Bool