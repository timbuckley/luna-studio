{-# LANGUAGE LambdaCase #-}

module Empire.ASTOps.Remove (
    removeArg
  , removeSubtree
  ) where

import           Control.Monad             (foldM)
import           Empire.Prelude

import           Empire.ASTOp              (GraphOp, match)
import           Empire.ASTOps.Deconstruct (deconstructApp)
import           Empire.ASTOps.Read        (isBlank)
import           Empire.Data.AST           (NodeRef, NotAppException (..))

import qualified Luna.IR                   as IR
import           Luna.IR.Term.Uni
import           OCI.IR.Combinators        (deleteSubtree)

removeSubtree :: GraphOp m => NodeRef -> m ()
removeSubtree ref = deleteSubtree ref

-- | Creates new App node with Blank inserted at specified position
removeArg :: GraphOp m => NodeRef -> Int -> m NodeRef
removeArg expr i = do
    (fun, args) <- deconstructApp expr
    b <- IR.generalize <$> IR.blank
    let args' = args & ix i .~ b
    a <- apps fun args'
    removeTrailingBlanks a

apps :: GraphOp m => IR.Expr f -> [NodeRef] -> m NodeRef
apps fun exprs = IR.unsafeRelayout <$> foldM f (IR.unsafeRelayout fun) (IR.unsafeRelayout <$> exprs)
    where
        f fun' arg' = appAny fun' arg'

appAny :: GraphOp m => NodeRef -> NodeRef -> m NodeRef
appAny = fmap IR.generalize .: IR.app

removeTrailingBlanks :: GraphOp m => NodeRef -> m NodeRef
removeTrailingBlanks expr = match expr $ \case
    App a c -> do
        argBlank <- isBlank =<< IR.source c
        if argBlank then removeTrailingBlanks =<< IR.source a
                    else return expr
    _ -> return expr
