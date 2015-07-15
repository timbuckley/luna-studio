{-# LANGUAGE OverloadedStrings #-}

module Reactive.Plugins.Core.Action.AddRemove where

import           Prelude       hiding       ( mapM_, forM_ )
import           Data.Foldable              ( mapM_, forM_ )
import           Control.Lens
import           Data.Default
import           Data.Maybe
import           Data.List
import           Data.Char
import           Data.Monoid
import           Data.Function

import qualified JS.Bindings    as UI
import qualified JS.NodeGraph   as UI
import qualified JS.Camera      as Camera

import           Object.Object
import qualified Object.Node    as Node     ( position )
import           Object.Node    hiding      ( position )
import           Event.Keyboard hiding      ( Event )
import qualified Event.Keyboard as Keyboard
import           Event.Mouse    hiding      ( Event, WithObjects )
import qualified Event.Mouse    as Mouse
import           Event.Event
import           Utils.Vector
import           Utils.Wrapper
import           Utils.PrettyPrinter
import           Reactive.Plugins.Core.Action.Action
import           Event.NodeSearcher hiding  ( Event, expression )
import qualified Event.NodeSearcher as NodeSearcher
import           Reactive.Plugins.Core.Action.State.AddRemove
import qualified Reactive.Plugins.Core.Action.State.Selection as Selection
import qualified Reactive.Plugins.Core.Action.State.Global    as Global

import qualified Data.Text.Lazy as Text
import           Data.Text.Lazy (Text)

data ActionType = Add
                | Remove
                deriving (Eq, Show)

data Action = AddAction Text
            | RemoveFocused
            deriving (Eq, Show)


makeLenses ''Action


instance PrettyPrinter ActionType where
    display = show

instance PrettyPrinter Action where
    display (AddAction expr) = "arA(AddAction " <> display expr <> ")"
    display RemoveFocused    = "arA(RemoveFocused)"


toAction :: Event Node -> Maybe Action
toAction (Keyboard (Keyboard.Event Keyboard.Press char)) = case char of
    'a'      -> Just $ AddAction "Hello.node"
    'r'      -> Just RemoveFocused
    _        -> Nothing
toAction (NodeSearcher (NodeSearcher.Event tpe expr)) = case tpe of
    "create" -> Just $ AddAction expr
    _        -> Nothing
toAction _    = Nothing

maxNodeId :: NodeCollection -> NodeId
maxNodeId []    = 0
maxNodeId nodes = (^. nodeId) $ maximumBy (on compare (^. nodeId)) nodes

-- mock helper functions
tmpGetInputPorts expr = (ord (head expr)) `mod` 6
tmpGetOutputPorts expr = 1 + (ord (fromMaybe 'a' $ listToMaybe (tail expr))) `mod` 3
-- end of mock

createNode :: NodeId -> Vector2 Double -> Text -> Node
createNode nodeId pos expr = Node nodeId False pos expr (inputPorts <> outputPorts) where
    inputPorts      = []
    outputPorts     = []


instance ActionStateUpdater Action where
    execSt newActionCandidate oldState = case newAction of
        Just action -> ActionUI newAction newState
        Nothing     -> ActionUI NoAction  newState
        where
        newState                = oldState & Global.iteration                     +~ 1
                                           & Global.nodes                         .~ newNodes
                                           & Global.selection . Selection.nodeIds .~ newSelIds
                                           & Global.addRemove . toRemoveIds       .~ newToRemoveIds
        oldNodes                = oldState ^. Global.nodes
        camera                  = Global.toCamera oldState
        nodePosWs               = Camera.screenToWorkspace camera $ oldState ^. Global.mousePos
        oldSelNodeIds           = oldState ^. Global.selection . Selection.nodeIds
        headNodeId              = listToMaybe oldSelNodeIds
        nextNodeId              = 1 + (maxNodeId oldNodes)
        newAction               = case newActionCandidate of
            RemoveFocused      -> case headNodeId of
                Nothing        -> Nothing
                _              -> Just newActionCandidate
            _                  -> Just newActionCandidate
        newToRemoveIds          = case newAction of
            Just RemoveFocused -> maybeToList headNodeId
            _                  -> []
        newSelIds               = case newAction of
            Just RemoveFocused -> drop 1 oldSelNodeIds
            _                  -> oldSelNodeIds
        newNodes                = case newActionCandidate of
            AddAction expr     -> newNode : oldNodes where
                newNode         = createNode nextNodeId nodePosWs expr
            RemoveFocused      -> case headNodeId of
                Nothing        -> oldNodes
                Just remId     -> filter (\node -> node ^. nodeId /= remId) oldNodes

instance ActionUIUpdater Action where
    updateUI (WithState action state) = case action of
        AddAction expr     -> createNodeOnUI node
            where
            node            = head $ state ^. Global.nodes
        RemoveFocused      -> UI.removeNode nodeId
                           >> mapM_ UI.setNodeFocused topNodeId
            where
            selectedNodeIds = state ^. Global.selection . Selection.nodeIds
            nodeId          = head $ state ^. Global.addRemove . toRemoveIds
            topNodeId       = selectedNodeIds ^? ix 0



createNodeOnUI :: Node ->  IO ()
createNodeOnUI node = do
    let
        pos        = node ^. Node.position
        ident      = node ^. nodeId
        expr       = node ^. expression
    -- putStrLn $ "ports " ++ show inputPorts ++ " " ++ show outputPorts
    UI.createNodeAt ident pos expr


