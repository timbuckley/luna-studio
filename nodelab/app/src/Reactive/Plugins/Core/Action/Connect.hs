module Reactive.Plugins.Core.Action.Connect where

import           Utils.PreludePlus
import           Utils.Vector
import           Utils.Angle (toAngle)
import qualified Utils.Nodes    as NodeUtils
import           Debug.Trace

import           Object.UITypes
import           Object.Widget                 (WidgetFile, widget, parent)
import qualified Object.Widget.Connection      as UIConnection
import qualified Object.Widget.Port            as PortModel
import qualified Object.Widget.Node            as NodeModel

import           Event.Keyboard                hiding      (Event)
import qualified Event.Keyboard                as Keyboard
import           Event.Mouse                   hiding      (Event, widget)
import qualified Event.Mouse                   as Mouse
import           Event.Event (Event(..))

import           Reactive.Commands.Graph
import           Reactive.Commands.Command     (Command, performIO, execCommand)
import qualified Reactive.Commands.UIRegistry  as UICmd
import qualified Reactive.State.Connect        as Connect
import           Reactive.State.Connect        (Connecting(..), DragHistory(..))
import qualified Reactive.State.Graph          as Graph
import qualified Reactive.State.UIRegistry     as UIRegistry
import qualified Reactive.State.Camera         as Camera
import qualified Reactive.State.Global         as Global
import           Reactive.State.Global         (State)

import qualified BatchConnector.Commands       as BatchCmd

import           Empire.API.Data.PortRef (InPortRef(..), OutPortRef(..), AnyPortRef(..))
import qualified Empire.API.Data.Node    as Node



toAction :: Event -> Maybe (Command State ())
toAction (Mouse _ event@(Mouse.Event Mouse.Pressed  _   Mouse.LeftButton _ (Just _))) = Just $ startDrag event
toAction (Mouse _ event@(Mouse.Event Mouse.Moved    pos Mouse.LeftButton _ _)) = Just $ whileConnecting $ handleMove pos
toAction (Mouse _ event@(Mouse.Event Mouse.Moved    _   _                _ _)) = Just $ whileConnecting $ stopDrag'
toAction (Mouse _ event@(Mouse.Event Mouse.Released _   Mouse.LeftButton _ _)) = Just $ whileConnecting $ stopDrag event
toAction _                                                                     = Nothing

showCurrentConnection :: Vector2 Double -> Vector2 Double -> Command UIRegistry.State ()
showCurrentConnection from to = UICmd.update_ UIRegistry.currentConnectionId $ (UIConnection.currentFrom    .~ from)
                                                                             . (UIConnection.currentTo      .~ to  )
                                                                             . (UIConnection.currentVisible .~ True)

setCurrentConnectionColor :: Int -> Command UIRegistry.State ()
setCurrentConnectionColor color = UICmd.update_ UIRegistry.currentConnectionId $ UIConnection.currentColor .~ color

hideCurrentConnection :: Command UIRegistry.State ()
hideCurrentConnection = UICmd.update_ UIRegistry.currentConnectionId $ UIConnection.currentVisible .~ False

getPortWidgetUnderCursor :: EventWidget -> Command UIRegistry.State (Maybe (WidgetFile PortModel.Port))
getPortWidgetUnderCursor (EventWidget widgetId _ _) = do
    file <- UIRegistry.lookupTypedM widgetId
    return file

startDrag :: Mouse.RawEvent -> Command State ()
startDrag event@(Mouse.Event _ coord _ _ (Just evWd)) = do
    sourcePortWd <- zoom Global.uiRegistry $ getPortWidgetUnderCursor evWd
    forM_ sourcePortWd $ \file -> do
        let model = file ^. widget
        let sourceRef = model ^. PortModel.portRef
        graph  <- use Global.graph
        camera <- use $ Global.camera . Camera.camera
        sourceNodePos <- zoom Global.uiRegistry $ UICmd.get (fromJust $ file ^. parent) NodeModel.position
        Global.connect . Connect.connecting ?= (Connecting sourceRef (evWd ^. Mouse.widgetId) (model ^. PortModel.angleVector) sourceNodePos Nothing (DragHistory coord coord))
        zoom Global.uiRegistry $ setCurrentConnectionColor $ model ^. PortModel.color

whileConnecting :: (Connect.Connecting -> Command State ()) -> Command State ()
whileConnecting run = do
    connectingMay <- use $ Global.connect . Connect.connecting
    forM_ connectingMay $ \connecting -> run connecting

handleMove :: Vector2 Int -> Connect.Connecting -> Command State ()
handleMove coord (Connecting sourceRef sourceWidget sourceVector nodePos _ (DragHistory start current)) = do
    graph  <- use Global.graph
    camera <- use $ Global.camera . Camera.camera
    Global.connect . Connect.connecting . _Just . Connect.history . Connect.dragCurrentPos .= coord
    start'   <- zoom Global.camera $ Camera.screenToWorkspaceM start
    current' <- zoom Global.camera $ Camera.screenToWorkspaceM coord
    zoom Global.uiRegistry $ do
        let newVector = sourceVector + (current' - nodePos)
        UICmd.update sourceWidget (PortModel.angleVector .~ newVector)
        let startLine = Vector2 sx sy where
            angle     = toAngle newVector
            sx        = (nodePos ^. x) + outerPos * cos angle
            sy        = (nodePos ^. y) + outerPos * sin angle
            outerPos  = portOuterBorder + distFromPort
        showCurrentConnection startLine current'
    updateConnections

stopDrag' :: Connect.Connecting -> Command State ()
stopDrag' _ = do
    Global.connect . Connect.connecting .= Nothing
    zoom Global.uiRegistry hideCurrentConnection
    updatePortAngles

toValidConnection :: AnyPortRef -> AnyPortRef -> Maybe (OutPortRef, InPortRef)
toValidConnection (OutPortRef' a) (InPortRef' b) = Just (a, b)
toValidConnection (InPortRef' a) (OutPortRef' b) = Just (b, a)
toValidConnection _ _ = Nothing

stopDrag :: Mouse.RawEvent -> Connect.Connecting -> Command State ()
stopDrag event@(Mouse.Event _ coord _ _ mayEvWd) (Connecting sourceRef _ _ _ _ (DragHistory start current)) = do
    Global.connect . Connect.connecting .= Nothing
    zoom Global.uiRegistry hideCurrentConnection

    graph <- use Global.graph
    nodesMap <- use $ Global.graph . Graph.nodesMap
    forM_ mayEvWd $ \evWd -> do
        destinationFile <- zoom Global.uiRegistry $ getPortWidgetUnderCursor evWd
        forM_ destinationFile $ \destinationFile -> do
            let destinationRef = destinationFile ^. widget . PortModel.portRef
            let srcDstMay = toValidConnection sourceRef destinationRef
            forM_ srcDstMay $ \(src, dst) -> do
                connectNodes src dst
    updatePortAngles
    updateConnections
