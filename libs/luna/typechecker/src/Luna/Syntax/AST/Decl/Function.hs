{-# LANGUAGE TypeOperators #-}

module Luna.Syntax.AST.Decl.Function where

import Prologue
import Luna.Syntax.Model.Graph

data FunctionPtr n = FunctionPtr { _self :: Maybe (Ref $ Node n)
                                 , _args :: [Ref $ Node n]
                                 , _out  :: Ref $ Node n
                                 } deriving (Show)
makeLenses ''FunctionPtr

data Function n = Function { _fptr  :: FunctionPtr n
                           , _graph :: Graph n (Link n)
                           } deriving (Show)
makeLenses ''Function
