{-# LANGUAGE CPP, MagicHash #-}

-- | Dynamically lookup up values from modules and loading them.
module GHCVM.Main.DynamicLoading (
#ifdef GHCI
        -- * Loading plugins
        loadPlugins,

        -- * Force loading information
        forceLoadModuleInterfaces,
        forceLoadNameModuleInterface,
        forceLoadTyCon,

        -- * Finding names
        lookupRdrNameInModuleForPlugins,

        -- * Loading values
        getValueSafely,
        getHValueSafely,
        lessUnsafeCoerce
#endif
    ) where

#ifdef GHCI
import GHCVM.Interactive.Linker           ( linkModule, getHValue )
import GHCVM.BasicTypes.SrcLoc           ( noSrcSpan )
import GHCVM.Main.Finder           ( findImportedModule, cannotFindModule )
import GHCVM.TypeCheck.TcRnMonad        ( initTcInteractive, initIfaceTcRn )
import GHCVM.Iface.LoadIface        ( loadPluginInterface )
import GHCVM.BasicTypes.RdrName          ( RdrName, Provenance(..), ImportSpec(..), ImpDeclSpec(..)
                        , ImpItemSpec(..), mkGlobalRdrEnv, lookupGRE_RdrName
                        , gre_name, mkRdrQual )
import GHCVM.BasicTypes.OccName          ( mkVarOcc )
import GHCVM.Rename.RnNames          ( gresFromAvails )
import GHCVM.Main.DynFlags
import GHCVM.Main.Plugins          ( Plugin, CommandLineOption )
import GHCVM.Prelude.PrelNames        ( pluginTyConName )

import GHCVM.Main.HscTypes
import GHCVM.BasicTypes.BasicTypes       ( HValue )
import GHCVM.Types.TypeRep          ( mkTyConTy, pprTyThingCategory )
import GHCVM.Types.Type             ( Type, eqType )
import GHCVM.Types.TyCon            ( TyCon )
import GHCVM.BasicTypes.Name             ( Name, nameModule_maybe )
import GHCVM.BasicTypes.Id               ( idType )
import GHCVM.BasicTypes.Module           ( Module, ModuleName )
import GHCVM.Utils.Panic
import GHCVM.Utils.FastString
import GHCVM.Main.ErrUtils
import GHCVM.Utils.Outputable
import GHCVM.Utils.Exception
import GHCVM.Main.Hooks

import Data.Maybe        ( mapMaybe )
import GHC.Exts          ( unsafeCoerce# )


loadPlugins :: HscEnv -> IO [(ModuleName, Plugin, [CommandLineOption])]
loadPlugins hsc_env
  = do { plugins <- mapM (loadPlugin hsc_env) to_load
       ; return $ map attachOptions $ to_load `zip` plugins }
  where
    dflags  = hsc_dflags hsc_env
    to_load = pluginModNames dflags

    attachOptions (mod_nm, plug) = (mod_nm, plug, options)
      where
        options = [ option | (opt_mod_nm, option) <- pluginModNameOpts dflags
                            , opt_mod_nm == mod_nm ]

loadPlugin :: HscEnv -> ModuleName -> IO Plugin
loadPlugin hsc_env mod_name
  = do { let plugin_rdr_name = mkRdrQual mod_name (mkVarOcc "plugin")
             dflags = hsc_dflags hsc_env
       ; mb_name <- lookupRdrNameInModuleForPlugins hsc_env mod_name
                        plugin_rdr_name
       ; case mb_name of {
            Nothing ->
                throwGhcExceptionIO (CmdLineError $ showSDoc dflags $ hsep
                          [ ptext (sLit "The module"), ppr mod_name
                          , ptext (sLit "did not export the plugin name")
                          , ppr plugin_rdr_name ]) ;
            Just name ->

     do { plugin_tycon <- forceLoadTyCon hsc_env pluginTyConName
        ; mb_plugin <- getValueSafely hsc_env name (mkTyConTy plugin_tycon)
        ; case mb_plugin of
            Nothing ->
                throwGhcExceptionIO (CmdLineError $ showSDoc dflags $ hsep
                          [ ptext (sLit "The value"), ppr name
                          , ptext (sLit "did not have the type")
                          , ppr pluginTyConName, ptext (sLit "as required")])
            Just plugin -> return plugin } } }


-- | Force the interfaces for the given modules to be loaded. The 'SDoc' parameter is used
-- for debugging (@-ddump-if-trace@) only: it is shown as the reason why the module is being loaded.
forceLoadModuleInterfaces :: HscEnv -> SDoc -> [Module] -> IO ()
forceLoadModuleInterfaces hsc_env doc modules
    = (initTcInteractive hsc_env $
       initIfaceTcRn $
       mapM_ (loadPluginInterface doc) modules) 
      >> return ()

-- | Force the interface for the module containing the name to be loaded. The 'SDoc' parameter is used
-- for debugging (@-ddump-if-trace@) only: it is shown as the reason why the module is being loaded.
forceLoadNameModuleInterface :: HscEnv -> SDoc -> Name -> IO ()
forceLoadNameModuleInterface hsc_env reason name = do
    let name_modules = mapMaybe nameModule_maybe [name]
    forceLoadModuleInterfaces hsc_env reason name_modules

-- | Load the 'TyCon' associated with the given name, come hell or high water. Fails if:
--
-- * The interface could not be loaded
-- * The name is not that of a 'TyCon'
-- * The name did not exist in the loaded module
forceLoadTyCon :: HscEnv -> Name -> IO TyCon
forceLoadTyCon hsc_env con_name = do
    forceLoadNameModuleInterface hsc_env (ptext (sLit "contains a name used in an invocation of loadTyConTy")) con_name
    
    mb_con_thing <- lookupTypeHscEnv hsc_env con_name
    case mb_con_thing of
        Nothing -> throwCmdLineErrorS dflags $ missingTyThingError con_name
        Just (ATyCon tycon) -> return tycon
        Just con_thing -> throwCmdLineErrorS dflags $ wrongTyThingError con_name con_thing
  where dflags = hsc_dflags hsc_env

-- | Loads the value corresponding to a 'Name' if that value has the given 'Type'. This only provides limited safety
-- in that it is up to the user to ensure that that type corresponds to the type you try to use the return value at!
--
-- If the value found was not of the correct type, returns @Nothing@. Any other condition results in an exception:
--
-- * If we could not load the names module
-- * If the thing being loaded is not a value
-- * If the Name does not exist in the module
-- * If the link failed

getValueSafely :: HscEnv -> Name -> Type -> IO (Maybe a)
getValueSafely hsc_env val_name expected_type = do
  mb_hval <- lookupHook getValueSafelyHook getHValueSafely dflags hsc_env val_name expected_type
  case mb_hval of
    Nothing   -> return Nothing
    Just hval -> do
      value <- lessUnsafeCoerce dflags "getValueSafely" hval
      return (Just value)
  where
    dflags = hsc_dflags hsc_env

getHValueSafely :: HscEnv -> Name -> Type -> IO (Maybe HValue)
getHValueSafely hsc_env val_name expected_type = do
    forceLoadNameModuleInterface hsc_env (ptext (sLit "contains a name used in an invocation of getHValueSafely")) val_name
    -- Now look up the names for the value and type constructor in the type environment
    mb_val_thing <- lookupTypeHscEnv hsc_env val_name
    case mb_val_thing of
        Nothing -> throwCmdLineErrorS dflags $ missingTyThingError val_name
        Just (AnId id) -> do
            -- Check the value type in the interface against the type recovered from the type constructor
            -- before finally casting the value to the type we assume corresponds to that constructor
            if expected_type `eqType` idType id
             then do
                -- Link in the module that contains the value, if it has such a module
                case nameModule_maybe val_name of
                    Just mod -> do linkModule hsc_env mod
                                   return ()
                    Nothing ->  return ()
                -- Find the value that we just linked in and cast it given that we have proved it's type
                hval <- getHValue hsc_env val_name
                return (Just hval)
             else return Nothing
        Just val_thing -> throwCmdLineErrorS dflags $ wrongTyThingError val_name val_thing
   where dflags = hsc_dflags hsc_env

-- | Coerce a value as usual, but:
--
-- 1) Evaluate it immediately to get a segfault early if the coercion was wrong
--
-- 2) Wrap it in some debug messages at verbosity 3 or higher so we can see what happened
--    if it /does/ segfault
lessUnsafeCoerce :: DynFlags -> String -> a -> IO b
lessUnsafeCoerce dflags context what = do
    debugTraceMsg dflags 3 $ (ptext $ sLit "Coercing a value in") <+> (text context) <> (ptext $ sLit "...")
    output <- evaluate (unsafeCoerce# what)
    debugTraceMsg dflags 3 $ ptext $ sLit "Successfully evaluated coercion"
    return output


-- | Finds the 'Name' corresponding to the given 'RdrName' in the
-- context of the 'ModuleName'. Returns @Nothing@ if no such 'Name'
-- could be found. Any other condition results in an exception:
--
-- * If the module could not be found
-- * If we could not determine the imports of the module
--
-- Can only be used for looking up names while loading plugins (and is
-- *not* suitable for use within plugins).  The interface file is
-- loaded very partially: just enough that it can be used, without its
-- rules and instances affecting (and being linked from!) the module
-- being compiled.  This was introduced by 57d6798.
--
-- See Note [Care with plugin imports] in LoadIface.
lookupRdrNameInModuleForPlugins :: HscEnv -> ModuleName -> RdrName -> IO (Maybe Name)
lookupRdrNameInModuleForPlugins hsc_env mod_name rdr_name = do
    -- First find the package the module resides in by searching exposed packages and home modules
    found_module <- findImportedModule hsc_env mod_name Nothing
    case found_module of
        Found _ mod -> do
            -- Find the exports of the module
            (_, mb_iface) <- initTcInteractive hsc_env $
                             initIfaceTcRn $
                             loadPluginInterface doc mod
            case mb_iface of
                Just iface -> do
                    -- Try and find the required name in the exports
                    let decl_spec = ImpDeclSpec { is_mod = mod_name, is_as = mod_name
                                                , is_qual = False, is_dloc = noSrcSpan }
                        provenance = Imported [ImpSpec decl_spec ImpAll]
                        env = mkGlobalRdrEnv (gresFromAvails provenance (mi_exports iface))
                    case lookupGRE_RdrName rdr_name env of
                        [gre] -> return (Just (gre_name gre))
                        []    -> return Nothing
                        _     -> panic "lookupRdrNameInModule"

                Nothing -> throwCmdLineErrorS dflags $ hsep [ptext (sLit "Could not determine the exports of the module"), ppr mod_name]
        err -> throwCmdLineErrorS dflags $ cannotFindModule dflags mod_name err
  where
    dflags = hsc_dflags hsc_env
    doc = ptext (sLit "contains a name used in an invocation of lookupRdrNameInModule")

wrongTyThingError :: Name -> TyThing -> SDoc
wrongTyThingError name got_thing = hsep [ptext (sLit "The name"), ppr name, ptext (sLit "is not that of a value but rather a"), pprTyThingCategory got_thing]

missingTyThingError :: Name -> SDoc
missingTyThingError name = hsep [ptext (sLit "The name"), ppr name, ptext (sLit "is not in the type environment: are you sure it exists?")]

throwCmdLineErrorS :: DynFlags -> SDoc -> IO a
throwCmdLineErrorS dflags = throwCmdLineError . showSDoc dflags

throwCmdLineError :: String -> IO a
throwCmdLineError = throwGhcExceptionIO . CmdLineError
#endif
