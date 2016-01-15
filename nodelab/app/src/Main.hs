module Main where


--      _|      _|
--      _|_|    _|    _|_|    _|      _|      _|
--      _|  _|  _|  _|_|_|_|  _|      _|      _|
--      _|    _|_|  _|          _|  _|  _|  _|
--      _|      _|    _|_|_|      _|      _|



--      _|_|_|                _|
--      _|    _|  _|    _|  _|_|_|_|    _|_|
--      _|_|_|    _|    _|    _|      _|_|_|_|
--      _|    _|  _|    _|    _|      _|
--      _|_|_|      _|_|_|      _|_|    _|_|_|
--                      _|
--                  _|_|

--        _|_|                    _|
--      _|    _|  _|  _|_|    _|_|_|    _|_|    _|  _|_|
--      _|    _|  _|_|      _|    _|  _|_|_|_|  _|_|
--      _|    _|  _|        _|    _|  _|        _|
--        _|_|    _|          _|_|_|    _|_|_|  _|


-- http://www.network-science.de/ascii/

import           Utils.PreludePlus

import           Reactive.Banana
import           Reactive.Banana.Frameworks (Frameworks, actuate)
import           JS.UI (initializeGl, render, triggerWindowResize)
import           JS.WebSocket
import           JS.Config
import qualified BatchConnector.Commands    as BatchCmd
import           Batch.Workspace
import           Utils.URIParser

import qualified Reactive.Plugins.Core.Network   as CoreNetwork
import           Reactive.Plugins.Loader.Loader
import           FakeMock (fakeWorkspace)


makeNetworkDescription :: forall t. Frameworks t => WebSocket -> Bool -> Workspace -> Moment t ()
makeNetworkDescription = CoreNetwork.makeNetworkDescription

runMainNetwork :: WebSocket -> Workspace -> IO ()
runMainNetwork socket workspace = do
    initializeGl
    render
    enableLogging <- isLoggerEnabled
    eventNetwork  <- compile $ makeNetworkDescription socket enableLogging workspace
    actuate eventNetwork
    triggerWindowResize
    BatchCmd.getProgram workspace

main :: IO ()
main = do
    socket <- getWebSocket
    backendAddr <- getBackendAddress
    connect socket backendAddr
    maybeProjectName <- getProjectName
    let projectName = maybe "myFirstProject" id maybeProjectName
    runMainNetwork socket fakeWorkspace

