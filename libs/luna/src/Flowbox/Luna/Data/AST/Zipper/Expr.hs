---------------------------------------------------------------------------
-- Copyright (C) Flowbox, Inc - All Rights Reserved
-- Unauthorized copying of this file, via any medium is strictly prohibited
-- Proprietary and confidential
-- Flowbox Team <contact@flowbox.io>, 2013
---------------------------------------------------------------------------
{-# LANGUAGE Rank2Types #-}
{-# LANGUAGE NoMonomorphismRestriction #-}

module Flowbox.Luna.Data.AST.Zipper.Expr where

import           Flowbox.Prelude                   hiding (id, drop)
import qualified Flowbox.Luna.Data.AST.Expr        as Expr
import           Flowbox.Luna.Data.AST.Expr          (Expr)
import qualified Flowbox.Luna.Data.AST.Module      as Module
import           Flowbox.Luna.Data.AST.Module        (Module)
import           Flowbox.Control.Monad.Trans.Maybe

import           Data.List                         (find)
import           Control.Error.Util                (hoistMaybe)
import           Control.Lens                      hiding (Zipper)  

--data Focus = FunctionFocus { expr :: Expr   , env :: FocusEnv }
--           | ClassFocus    { expr :: Expr   , env :: FocusEnv }
--           | ModuleFocus   { mod  :: Module , env :: FocusEnv }
--           deriving (Show)

data Focus  = FunctionFocus Expr
            | ModuleEnv Module
            deriving (Show)

type FocusPath = [Focus]

type Zipper = (Focus, FocusPath)

mk :: Module -> Maybe Zipper
mk rootmod = Just (ModuleEnv rootmod, [])

defocus :: Zipper -> Zipper
defocus zipper@(env, [])   = zipper
defocus (env, parent:path) = (newenv, path) where
    newenv = case parent of
        ModuleEnv pmod -> ModuleEnv $ case env of
            FunctionFocus func -> Module.addMethod func pmod


modify :: (Focus -> Focus) -> Zipper -> Maybe Zipper
modify f (env, path) = Just (f env, path)


close :: Zipper -> Maybe Module
close zipper@(env, []) = Just mod where ModuleEnv mod = env
close zipper           = close $ defocus zipper


focusFunction :: String -> Zipper -> Maybe Zipper
focusFunction name zipper@(env, path) = case env of
    ModuleEnv mod -> focusListElem Module.methods Expr.name 
                     FunctionFocus ModuleEnv mod name zipper
    _             -> Nothing


focusListElem :: Lens' a [b] -> Traversal' b String -> (b -> Focus) -> (a -> Focus) -> a -> String -> Zipper -> Maybe Zipper
focusListElem lens nameLens elemFocus crumbFocus elem name (env, path) = runMaybe $ do
    let funcs    = elem ^. lens
        mfunc    = find (\f -> f ^. nameLens == name) funcs
        newfuncs = [ f | f <- funcs, f ^. nameLens /= name ]
        newelem  = elem & lens .~ newfuncs 
    func <- hoistMaybe mfunc
    return $ (elemFocus func, (crumbFocus newelem) : path)



