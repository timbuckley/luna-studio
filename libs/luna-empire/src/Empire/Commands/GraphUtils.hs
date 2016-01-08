module Empire.Commands.GraphUtils where

import           Prologue
import           Control.Monad.State
import           Control.Monad.Error     (throwError)

import qualified Empire.Data.Graph       as Graph
import           Empire.Data.Graph       (Graph)

import           Empire.API.Data.Node    (NodeId)

import           Empire.Empire
import qualified Empire.Commands.AST     as AST
import           Luna.Syntax.Repr.Graph  (Ref, Node)

getASTPointer :: NodeId -> Command Graph (Ref Node)
getASTPointer nodeId = use (Graph.nodeMapping . at nodeId) <?!> "Node does not exist"

getASTTarget :: NodeId -> Command Graph (Ref Node)
getASTTarget nodeId = do
    unifyNode <- getASTPointer nodeId
    zoom Graph.ast $ AST.getTargetNode unifyNode

getASTVar :: NodeId -> Command Graph (Ref Node)
getASTVar nodeId = do
    unifyNode <- getASTPointer nodeId
    zoom Graph.ast $ AST.getVarNode unifyNode

