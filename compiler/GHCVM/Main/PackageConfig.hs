{-# LANGUAGE CPP, RecordWildCards #-}

-- |
-- Package configuration information: essentially the interface to Cabal, with
-- some utilities
--
-- (c) The University of Glasgow, 2004
--
module GHCVM.Main.PackageConfig (
        -- $package_naming

        -- * PackageKey
        packageConfigId,

        -- * The PackageConfig type: information about a package
        PackageConfig,
        InstalledPackageInfo(..),
        InstalledPackageId(..),
        SourcePackageId(..),
        PackageName(..),
        Version(..),
        defaultPackageConfig,
        installedPackageIdString,
        sourcePackageIdString,
        packageNameString,
        pprPackageConfig,
    ) where

#include "HsVersions.h"

import GHCVM.PackageDb
import Data.Version

import GHCVM.Utils.FastString
import GHCVM.Utils.Outputable
import GHCVM.BasicTypes.Module
import qualified GHCVM.BasicTypes.Module as Module

-- -----------------------------------------------------------------------------
-- Our PackageConfig type is the InstalledPackageInfo from bin-package-db,
-- which is similar to a subset of the InstalledPackageInfo type from Cabal.

type PackageConfig = InstalledPackageInfo
                       InstalledPackageId
                       SourcePackageId
                       PackageName
                       Module.PackageKey
                       Module.ModuleName

-- TODO: there's no need for these to be FastString, as we don't need the uniq
--       feature, but ghc doesn't currently have convenient support for any
--       other compact string types, e.g. plain ByteString or Text.

newtype InstalledPackageId = InstalledPackageId FastString deriving (Eq, Ord)
newtype SourcePackageId    = SourcePackageId    FastString deriving (Eq, Ord)
newtype PackageName        = PackageName        FastString deriving (Eq, Ord)

instance BinaryStringRep InstalledPackageId where
  fromStringRep = InstalledPackageId . mkFastStringByteString
  toStringRep (InstalledPackageId s) = fastStringToByteString s

instance BinaryStringRep SourcePackageId where
  fromStringRep = SourcePackageId . mkFastStringByteString
  toStringRep (SourcePackageId s) = fastStringToByteString s

instance BinaryStringRep PackageName where
  fromStringRep = PackageName . mkFastStringByteString
  toStringRep (PackageName s) = fastStringToByteString s

instance Outputable InstalledPackageId where
  ppr (InstalledPackageId str) = ftext str

instance Outputable SourcePackageId where
  ppr (SourcePackageId str) = ftext str

instance Outputable PackageName where
  ppr (PackageName str) = ftext str

-- | Pretty-print an 'ExposedModule' in the same format used by the textual
-- installed package database.
pprExposedModule :: (Outputable a, Outputable b) => ExposedModule a b -> SDoc
pprExposedModule (ExposedModule exposedName exposedReexport exposedSignature) =
    sep [ ppr exposedName
        , case exposedReexport of
            Just m -> sep [text "from", pprOriginalModule m]
            Nothing -> empty
        , case exposedSignature of
            Just m -> sep [text "is", pprOriginalModule m]
            Nothing -> empty
        ]

-- | Pretty-print an 'OriginalModule' in the same format used by the textual
-- installed package database.
pprOriginalModule :: (Outputable a, Outputable b) => OriginalModule a b -> SDoc
pprOriginalModule (OriginalModule originalPackageId originalModuleName) =
    ppr originalPackageId <> char ':' <> ppr originalModuleName

defaultPackageConfig :: PackageConfig
defaultPackageConfig = emptyInstalledPackageInfo

installedPackageIdString :: PackageConfig -> String
installedPackageIdString pkg = unpackFS str
  where
    InstalledPackageId str = installedPackageId pkg

sourcePackageIdString :: PackageConfig -> String
sourcePackageIdString pkg = unpackFS str
  where
    SourcePackageId str = sourcePackageId pkg

packageNameString :: PackageConfig -> String
packageNameString pkg = unpackFS str
  where
    PackageName str = packageName pkg

pprPackageConfig :: PackageConfig -> SDoc
pprPackageConfig InstalledPackageInfo {..} =
    vcat [
      field "name"                 (ppr packageName),
      field "version"              (text (showVersion packageVersion)),
      field "id"                   (ppr installedPackageId),
      field "key"                  (ppr packageKey),
      field "exposed"              (ppr exposed),
      field "exposed-modules"
        (if all isExposedModule exposedModules
           then fsep (map pprExposedModule exposedModules)
           else pprWithCommas pprExposedModule exposedModules),
      field "hidden-modules"       (fsep (map ppr hiddenModules)),
      field "trusted"              (ppr trusted),
      field "import-dirs"          (fsep (map text importDirs)),
      field "library-dirs"         (fsep (map text libraryDirs)),
      field "hs-libraries"         (fsep (map text hsLibraries)),
      field "extra-libraries"      (fsep (map text extraLibraries)),
      field "extra-ghci-libraries" (fsep (map text extraGHCiLibraries)),
      field "include-dirs"         (fsep (map text includeDirs)),
      field "includes"             (fsep (map text includes)),
      field "depends"              (fsep (map ppr  depends)),
      field "cc-options"           (fsep (map text ccOptions)),
      field "ld-options"           (fsep (map text ldOptions)),
      field "framework-dirs"       (fsep (map text frameworkDirs)),
      field "frameworks"           (fsep (map text frameworks)),
      field "haddock-interfaces"   (fsep (map text haddockInterfaces)),
      field "haddock-html"         (fsep (map text haddockHTMLs))
    ]
  where
    field name body = text name <> colon <+> nest 4 body
    isExposedModule (ExposedModule _ Nothing Nothing) = True
    isExposedModule _ = False


-- -----------------------------------------------------------------------------
-- PackageKey (package names, versions and dep hash)

-- $package_naming
-- #package_naming#
-- Mostly the compiler deals in terms of 'PackageKey's, which are md5 hashes
-- of a package ID, keys of its dependencies, and Cabal flags. You're expected
-- to pass in the package key in the @-this-package-key@ flag. However, for
-- wired-in packages like @base@ & @rts@, we don't necessarily know what the
-- version is, so these are handled specially; see #wired_in_packages#.

-- | Get the GHC 'PackageKey' right out of a Cabalish 'PackageConfig'
packageConfigId :: PackageConfig -> PackageKey
packageConfigId = packageKey
