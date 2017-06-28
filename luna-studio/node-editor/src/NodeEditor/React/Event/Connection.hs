{-# LANGUAGE DeriveAnyClass #-}

module NodeEditor.React.Event.Connection where

import           Common.Prelude
import           NodeEditor.React.Model.Connection (ConnectionId)
import           React.Flux                        (MouseEvent)



data ModifiedEnd = Source | Destination deriving (Eq, Generic, NFData, Show, Typeable)

data Event = MouseDown MouseEvent ConnectionId ModifiedEnd deriving (Show, Generic, NFData, Typeable)