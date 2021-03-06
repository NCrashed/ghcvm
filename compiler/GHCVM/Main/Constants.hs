{-
(c) The GRASP/AQUA Project, Glasgow University, 1992-1998

\section[Constants]{Info about this compilation}
-}

module GHCVM.Main.Constants where


hiVersion :: Integer
hiVersion = read (cProjectVersionInt ++ cProjectPatchLevel) :: Integer

cProjectName, cProjectVersion, cProjectVersionInt, cProjectPatchLevel, cProjectPatchLevel1,
  cProjectPatchLevel2, cProjectHomeURL, cProjectIssueReportURL, ghcProjectVersion,
  ghcProjectVersionInt, ghcprojectPatchLevel, ghcProjectPatchLevel1, ghcProjectPatchLevel2
  :: String
cProjectName = "Glasgow Haskell Compiler for the Java Virtual Machine"
cProjectVersion = "0.0.1"
cProjectVersionInt = "000"
cProjectPatchLevel = "1"
cProjectPatchLevel1 = "1"
cProjectPatchLevel2 = ""
cProjectHomeURL = "http://github.org/rahulmutt/ghcvm"
cProjectIssueReportURL = cProjectHomeURL ++ "/issues"
ghcProjectVersion = "7.10.3"
ghcProjectVersionInt = "710"
ghcprojectPatchLevel = "3"
ghcProjectPatchLevel1 = "3"
ghcProjectPatchLevel2 = ""

-- All pretty arbitrary:

mAX_TUPLE_SIZE :: Int
mAX_TUPLE_SIZE = 62 -- Should really match the number
                    -- of decls in Data.Tuple

mAX_CONTEXT_REDUCTION_DEPTH :: Int
mAX_CONTEXT_REDUCTION_DEPTH = 100
  -- Trac #5395 reports at least one library that needs depth 37 here

mAX_TYPE_FUNCTION_REDUCTION_DEPTH :: Int
mAX_TYPE_FUNCTION_REDUCTION_DEPTH = 200
  -- Needs to be much higher than mAX_CONTEXT_REDUCTION_DEPTH; see Trac #5395

wORD64_SIZE :: Int
wORD64_SIZE = 8

tARGET_MAX_CHAR :: Int
tARGET_MAX_CHAR = 0x10ffff

mAX_INTLIKE, mIN_INTLIKE, mAX_CHARLIKE, mIN_CHARLIKE, mAX_SPEC_AP_SIZE :: Int
mIN_INTLIKE = -16
mAX_INTLIKE = 16
mIN_CHARLIKE = 0
mAX_CHARLIKE = 255
mAX_SPEC_AP_SIZE = 7
