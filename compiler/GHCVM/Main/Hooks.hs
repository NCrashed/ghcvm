-- \section[Hooks]{Low level API hooks}

-- NB: this module is SOURCE-imported by DynFlags, and should primarily
--     refer to *types*, rather than *code*
-- If you import too muchhere , then the revolting compiler_stage2_dll0_MODULES
-- stuff in compiler/ghc.mk makes DynFlags link to too much stuff

module GHCVM.Main.Hooks ( Hooks
             , emptyHooks
             , lookupHook
             , getHooked
               -- the hooks:
             , dsForeignsHook
             , tcForeignImportsHook
             , tcForeignExportsHook
             , hscFrontendHook
             , hscCompileOneShotHook
             , hscCompileCoreExprHook
             , ghcPrimIfaceHook
             , runPhaseHook
             , runMetaHook
             , linkHook
             , runQuasiQuoteHook
             , runRnSpliceHook
             , getValueSafelyHook
             ) where

import GHCVM.Main.DynFlags
import GHCVM.HsSyn.HsTypes
import GHCVM.BasicTypes.Name
import GHCVM.Main.PipelineMonad
import GHCVM.Main.HscTypes
import GHCVM.HsSyn.HsDecls
import GHCVM.HsSyn.HsBinds
import GHCVM.HsSyn.HsExpr
import GHCVM.Utils.OrdList
import GHCVM.BasicTypes.Id
import GHCVM.TypeCheck.TcRnTypes
import GHCVM.Utils.Bag
import GHCVM.BasicTypes.RdrName
import GHCVM.Core.CoreSyn
import GHCVM.BasicTypes.BasicTypes
import GHCVM.Types.Type
import GHCVM.BasicTypes.SrcLoc

import Data.Maybe

{-
************************************************************************
*                                                                      *
\subsection{Hooks}
*                                                                      *
************************************************************************
-}

-- | Hooks can be used by GHC API clients to replace parts of
--   the compiler pipeline. If a hook is not installed, GHC
--   uses the default built-in behaviour

emptyHooks :: Hooks
emptyHooks = Hooks Nothing Nothing Nothing Nothing Nothing Nothing
                   Nothing Nothing Nothing Nothing Nothing Nothing
                   Nothing

data Hooks = Hooks
  { dsForeignsHook         :: Maybe ([LForeignDecl Id] -> DsM (ForeignStubs, OrdList (Id, CoreExpr)))
  , tcForeignImportsHook   :: Maybe ([LForeignDecl Name] -> TcM ([Id], [LForeignDecl Id], Bag GlobalRdrElt))
  , tcForeignExportsHook   :: Maybe ([LForeignDecl Name] -> TcM (LHsBinds TcId, [LForeignDecl TcId], Bag GlobalRdrElt))
  , hscFrontendHook        :: Maybe (ModSummary -> Hsc TcGblEnv)
  , hscCompileOneShotHook  :: Maybe (HscEnv -> ModSummary -> SourceModified -> IO HscStatus)
  , hscCompileCoreExprHook :: Maybe (HscEnv -> SrcSpan -> CoreExpr -> IO HValue)
  , ghcPrimIfaceHook       :: Maybe ModIface
  , runPhaseHook           :: Maybe (PhasePlus -> FilePath -> DynFlags -> CompPipeline (PhasePlus, FilePath))
  , runMetaHook            :: Maybe (MetaHook TcM)
  , linkHook               :: Maybe (GhcLink -> DynFlags -> Bool -> HomePackageTable -> IO SuccessFlag)
  , runQuasiQuoteHook      :: Maybe (HsQuasiQuote Name -> RnM (HsQuasiQuote Name))
  , runRnSpliceHook        :: Maybe (LHsExpr Name -> RnM (LHsExpr Name))
  , getValueSafelyHook     :: Maybe (HscEnv -> Name -> Type -> IO (Maybe HValue))
  }

getHooked :: (Functor f, HasDynFlags f) => (Hooks -> Maybe a) -> a -> f a
getHooked hook def = fmap (lookupHook hook def) getDynFlags

lookupHook :: (Hooks -> Maybe a) -> a -> DynFlags -> a
lookupHook hook def = fromMaybe def . hook . hooks
