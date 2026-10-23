{-# LANGUAGE FlexibleInstances #-}
{-# LANGUAGE ForeignFunctionInterface #-}
{-# LANGUAGE MultiParamTypeClasses #-}
{-# LANGUAGE RecordWildCards #-}
{-# LANGUAGE ScopedTypeVariables #-}
{-# LANGUAGE UndecidableInstances #-}
{-# OPTIONS_GHC -fno-cse #-}
{-# OPTIONS_GHC -fno-full-laziness #-}

module QuickCheckWithFandango
  ( qcfDefaults,
    qcfMakeProp,
    qcfMakeResult,
    qcfRunArb,
    qcfRunArb',
    -- fandangoGen,
    fandangoGenBST,
    fandangoGenKey,
    fandangoGenVal
    -- Fandango(..),
  )
where

import Etna.Lib.Types
import Control.Monad (unless, when)
import Data.IORef (IORef, newIORef, readIORef, writeIORef)
import Foreign.C.String (CString, peekCString, withCString)
import Foreign.C.Types (CInt(..))
import Foreign.Marshal.Alloc (free)
import Foreign.Ptr (nullPtr)
import System.IO (hPutStrLn, stderr)
import System.IO.Silently (capture)
import System.IO.Unsafe (unsafePerformIO)
import Test.QuickCheck hiding (Result)
import Test.QuickCheck.Gen (Gen (MkGen))
import qualified Test.QuickCheck as QC
import Debug.Trace
import Spec

-- To use QuickCheck, can just implement an Arbitrary instance
-- and call (qcRunArb qcDefaults [approach]), where approach
-- should be Naive if your generator does not necessarily generate 
-- inputs that satisfy the precondition, and Correct otherwise.

qcfDefaults :: Args
qcfDefaults = 
  -- By default, use timeout instead of max tests.
  stdArgs {maxSuccess = 1000} 

qcfMakeProp :: Approach -> Task a -> (a -> Property)
qcfMakeProp Naive task =
  -- Filter based on precondition.
  uncurry (==>) . task
qcfMakeProp Correct task =
  -- Only evaluate postcondition.
  QC.property . snd . task

qcfMakeResult :: IO QC.Result -> IO Result
qcfMakeResult ioresult = do
  (_, result) <- capture ioresult
  let (foundbug, output) =
        case result of
          Failure {failingTestCase = [ex]} -> (True, ex)
          NoExpectedFailure {} -> (True, "")
          _ -> (False, "")
      discards = Just $ numDiscarded result
      passed = numTests result - (if foundbug then 1 else 0)
  return Result {..}

qcfRunArb :: (Show a, Arbitrary a) => Args -> Approach -> Strategy a
qcfRunArb args app = qcfRunArb' args . qcfMakeProp app

qcfRunArb' :: (Show a, Arbitrary a) => Args -> (a -> Property) -> IO Result
qcfRunArb' args prop = qcfMakeResult $ quickCheckWithResult args prop

-- fandangoGen :: Read a => String -> Gen a
-- fandangoGen start = pure $ unsafePerformIO $ do
--     output <- readProcess "/Users/jeb/Workspace/hsk-demo/.venv/bin/fandango" ["fuzz", "-f", "./grammar.fan", "-n", "1", "-S", start] ""
--     return (trace ("Gen: " ++ output) $ read output)

-- fandangoGenKey :: Gen Key
-- fandangoGenKey = pure $ unsafePerformIO $ do
--     output <- readProcess "/Users/jeb/Workspace/hsk-demo/.venv/bin/fandango" ["fuzz", "-f", "./grammar.fan", "-n", "1", "-S", "<key>"] ""
--     return (trace ("GenKey: " ++ output) $ read output)

-- fandangoGenBST :: Gen BST
-- fandangoGenBST = pure $ unsafePerformIO $ do
--     output <- readProcess "/Users/jeb/Workspace/hsk-demo/.venv/bin/fandango" ["fuzz", "-f", "./grammar.fan", "-n", "1", "-S", "<tree>"] ""
--     return (trace ("GenBST: " ++ output) $ read output)

-- fandangoGenVal :: Gen Val
-- fandangoGenVal = pure $ unsafePerformIO $ do
--     output <- readProcess "/Users/jeb/Workspace/hsk-demo/.venv/bin/fandango" ["fuzz", "-f", "./grammar.fan", "-n", "1", "-S", "<val>"] ""
--     return (trace ("GenVal: " ++ output) $ read output)

fandangoGenKey :: Gen Key
fandangoGenKey = traceChoice "GenKey" <$> fandangoGen "<key>"

fandangoGenBST :: Gen BST
fandangoGenBST = traceChoice "GenBST" <$> fandangoGen "<tree>"

fandangoGenVal :: Gen Val
fandangoGenVal = traceChoice "GenVal" <$> fandangoGen "<value>"

traceChoice :: Show a => String -> a -> a
traceChoice tag x = trace (tag ++ ": " ++ show x) x

{-# NOINLINE fandangoGen #-}
fandangoGen :: (Read a, Show a) => String -> Gen a
fandangoGen start = MkGen $ \r n ->
  r `seq` n `seq`
    unsafePerformIO $ do
      ensureSetup
      sample <- fandangoNext start
      pure $ trace (start ++ " sample: " ++ show sample) sample

fandangoNext :: Read a => String -> IO a
fandangoNext start = do
  raw <- withCString start $ \cStart -> do
    cStr <- c_inc_gen_with_start cStart
    if cStr == nullPtr
      then fail ("fandango FFI returned NULL for " ++ start)
      else do
        hs <- peekCString cStr
        free cStr
        pure hs
  hPutStrLn stderr ("fandango sample " ++ start ++ ": " ++ raw)
  parseSample start raw

parseSample :: Read a => String -> String -> IO a
parseSample tag raw =
  case reads raw of
    [(value, "")] -> pure value
    _ -> fail ("failed to parse " ++ tag ++ " sample: " ++ raw)

{-# NOINLINE setupRef #-}
setupRef :: IORef Bool
setupRef = unsafePerformIO (newIORef False)

ensureSetup :: IO ()
ensureSetup = do
  already <- readIORef setupRef
  unless already $ do
    result <- c_setup
    when (result /= 0) (fail ("failed to initialize FFI generator " ++ show result))
    writeIORef setupRef True

foreign import ccall safe "setup" c_setup :: IO CInt
foreign import ccall safe "inc_gen_with_start" c_inc_gen_with_start :: CString -> IO CString

newtype Fandango a = Fandango a deriving (Read, Show)
