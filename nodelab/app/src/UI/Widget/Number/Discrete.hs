module UI.Widget.Number.Discrete where

import           Utils.PreludePlus
import           Utils.Vector
import           Data.Text.Lazy                (Text)

import qualified Data.JSString                 as JSString
import           Data.JSString.Text            (lazyTextToJSString)
import           GHCJS.Foreign

import           Object.UITypes
import           Object.Widget
import qualified Object.Widget.Number.Discrete as Model

import           UI.Generic                    (whenChanged)
import qualified UI.Generic                    as UI
import qualified UI.Registry                   as UI
import qualified UI.Widget                     as Widget
import           UI.Widget.Number              (Number, create', setFocus', setLabel', setValueLabel')

createNumber :: WidgetId -> Model.DiscreteNumber -> IO Number
createNumber oid model = do
    slider   <- create' oid (model ^. Model.size . x) (model ^. Model.size . y)
    setLabel    model slider
    UI.setWidgetPosition (model ^. Model.position) slider
    return slider

setLabel :: Model.DiscreteNumber-> Number -> IO ()
setLabel model slider = setLabel' slider $ lazyTextToJSString $ model ^. Model.label

instance UIDisplayObject Model.DiscreteNumber where
    createUI parentId id model = do
        slider   <- createNumber id model
        parent <- UI.lookup parentId :: IO Widget.GenericWidget
        UI.register id slider
        Widget.add slider parent

    updateUI id old model = do
        slider <- UI.lookup id :: IO Number
        whenChanged old model Model.label $ setLabel model slider
        whenChanged old model Model.size  $ UI.setSize id model
