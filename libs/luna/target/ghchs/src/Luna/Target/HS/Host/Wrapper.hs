---------------------------------------------------------------------------
-- Copyright (C) Flowbox, Inc - All Rights Reserved
-- Unauthorized copying of this file, via any medium is strictly prohibited
-- Proprietary and confidential
-- Flowbox Team <contact@flowbox.io>, 2014
---------------------------------------------------------------------------

{-# LANGUAGE NoMonomorphismRestriction #-}
{-# LANGUAGE DataKinds #-}
{-# LANGUAGE FlexibleContexts #-}
{-# LANGUAGE PolyKinds #-} -- needed by mainMaker

module Luna.Target.HS.Host.Wrapper where

import Control.Monad
import Data.Typeable
import Luna.Target.HS.Control
import Luna.Target.HS.Data
import Luna.Target.HS.Host.Lift
import Control.Monad.Shuffle


checkVal = join . fmap printCheck . toIOEnv

mainMaker modCons = toIOEnv $ fromValue $ call $ member (Proxy::Proxy "main") $ call modCons

mainMaker2 modCons = checkVal $ fromValueS $ call2 $ member2 (Proxy::Proxy "main") $ call2 modCons


rangeFromTo' a b = if a <= b then [a..b]
                             else [a,a-1..b]

rangeFromTo = liftF2 rangeFromTo'

concatPure = (fmap.fmap.fmap) val . (fmap.fmap) concat . (fmap sequence) . sequence

ifThenElse cond a b = if cond then a else b

ifThenElse' cond a b = shuffleJoin $ (fmap.fmap) (\x -> ifThenElse x a b) cond