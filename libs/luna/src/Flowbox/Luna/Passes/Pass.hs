---------------------------------------------------------------------------
-- Copyright (C) Flowbox, Inc - All Rights Reserved
-- Unauthorized copying of this file, via any medium is strictly prohibited
-- Proprietary and confidential
-- Flowbox Team <contact@flowbox.io>, 2013
---------------------------------------------------------------------------
{-# LANGUAGE FlexibleContexts, NoMonomorphismRestriction, ConstraintKinds, TupleSections #-}

module Flowbox.Luna.Passes.Pass where

import           Flowbox.Prelude              
import           Control.Monad.State          

import           Control.Monad.RWS            
import           Control.Monad.Trans.Either   

import           Flowbox.System.Log.Logger    
import qualified Flowbox.System.Log.Logger  as Logger

import           Prelude                    hiding (fail)
import qualified Prelude                    as Prelude


type PassMonad    s m       = (Functor m, MonadState s m, LogWriter m)
type Transformer  s a m b   = EitherT a (RWS [Int] LogList s) b -> EitherT a m b
type TransformerT s a m b   = EitherT a (RWST [Int] LogList s m) b -> m (Either a b)
type Result       m output  = EitherT String m output

data NoState = NoState deriving (Show)


run :: state -> EitherT a (RWS [Int] LogList state) b -> (Either a b, state, LogList)
run s f = runRWS (runEitherT f) [] s


--run :: state -> EitherT a (RWS [Int] LogList state) b -> (Either a b, state, LogList)
runT s f = runRWST (runEitherT f) [] s


runM :: PassMonad s m => state -> Transformer state a m b 
runM s f = do
    let (nast, _, logs) = run s f
    Logger.append logs
    hoistEither nast


fail :: Monad m => String -> EitherT String m a
fail = left