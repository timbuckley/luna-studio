{-# LANGUAGE OverloadedStrings #-}

module Empire.Server.Graph where

import           Prologue

import qualified Data.Binary                 as Bin
import           Control.Monad.State         (StateT, get, put)
import           Flowbox.Bus.BusT            (BusT (..))
import qualified Empire.Env                  as Env
import           Empire.Env                  (Env)
import           Data.Map.Strict             (Map)
import           Data.ByteString             (ByteString)
import           Data.ByteString.Char8       (unpack)
import           Data.ByteString.Lazy        (fromStrict, toStrict)

import qualified Flowbox.Bus.Data.Flag       as Flag
import qualified Flowbox.Bus.Data.Message    as Message
import qualified Flowbox.Bus.Bus             as Bus
import           Flowbox.Bus.BusT            (BusT (..))
import qualified Flowbox.Bus.BusT            as Bus

import qualified Empire.API.Data.Node        as Node
import qualified Empire.API.Data.NodeMeta    as NodeMeta
import           Empire.API.Data.Library     (LibraryId)
import           Empire.API.Data.Project     (ProjectId)
import qualified Empire.API.Topic            as Topic
import qualified Empire.API.Graph.AddNode    as AddNode
import qualified Empire.API.Graph.RemoveNode as RemoveNode
import qualified Empire.API.Data.NodeMeta    as NodeMeta
import qualified Empire.API.Response         as Response

import qualified Empire.Commands.Graph       as Graph
import           Empire.Data.AST             (AST)
import qualified Empire.Empire               as Empire
import           Empire.Empire               (Empire)

import           Flowbox.System.Log.Logger

logger :: LoggerIO
logger = getLoggerIO $moduleName


addNode :: ProjectId -> LibraryId -> String -> Empire ()
addNode pid lid expr = do
    nodeId <- Graph.addNode pid lid expr
    return ()

handleAddNode :: ByteString -> StateT Env BusT ()
handleAddNode content = do
    logger info $ "Handling AddNodeRequest"
    let req = Bin.decode . fromStrict $ content :: AddNode.Request
    logger info $ show req
    env <- get
    logger info $ show env
    (graph, st) <- liftIO $ Empire.runEmpire (env ^. Env.empire) (addNode (req ^. AddNode.projectId) (req ^. AddNode.libraryId) (req ^. AddNode.expr))
    let meta     = NodeMeta.NodeMeta (20.0, 30.0)
        request  = AddNode.Request 0 0 "dupa123" meta 1235
        node     = Node.Node 123 "dupa123" mempty meta
        update   = AddNode.Update  node
        response = Response.Update request update
    lift $ BusT $ Bus.send Flag.Enable $ Message.Message "empire.graph.node.add.update" $ toStrict $ Bin.encode response
    return ()

handleRemoveNode :: ByteString -> StateT Env BusT ()
handleRemoveNode content = do
    logger info $ "Handling RemoveNodeRequest"
    let removeNodeRequest = Bin.decode . fromStrict $ content :: RemoveNode.Request
    logger info $ show removeNodeRequest
