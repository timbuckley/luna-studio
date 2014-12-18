---------------------------------------------------------------------------
-- Copyright (C) Flowbox, Inc - All Rights Reserved
-- Unauthorized copying of this file, via any medium is strictly prohibited
-- Proprietary and confidential
-- Flowbox Team <contact@flowbox.io>, 2014
---------------------------------------------------------------------------
{-# LANGUAGE NoMonomorphismRestriction #-}
{-# LANGUAGE UndecidableInstances #-}
{-# LANGUAGE RankNTypes #-}
{-# LANGUAGE ScopedTypeVariables #-}
{-# LANGUAGE OverlappingInstances #-}

module Luna.Pass2.Transform.Hash where

import           Flowbox.Prelude              hiding (Traversal)
import           Flowbox.Control.Monad.State  hiding (mapM_, (<$!>), join, mapM, State)
import qualified Luna.ASTNew.Traversals       as AST
import qualified Luna.ASTNew.Enum             as Enum
import           Luna.ASTNew.Enum             (Enumerated, IDTag(IDTag))
import qualified Luna.ASTNew.Decl             as Decl
import           Luna.ASTNew.Decl             (LDecl, Field(Field))
import qualified Luna.ASTNew.Module           as Module
import           Luna.ASTNew.Module           (Module(Module), LModule)
import           Luna.ASTNew.Unit             (Unit(Unit))
import qualified Luna.ASTNew.Label            as Label
import           Luna.ASTNew.Label            (Label(Label))
import qualified Luna.ASTNew.Type             as Type
import           Luna.ASTNew.Type             (Type)
import qualified Luna.ASTNew.Pat              as Pat
import           Luna.ASTNew.Pat              (LPat, Pat)
import           Luna.ASTNew.Expr             (LExpr, Expr)
import qualified Luna.ASTNew.Lit              as Lit
import qualified Luna.ASTNew.Native           as Native
import qualified Luna.ASTNew.Name             as Name
import           Luna.ASTNew.Name             (TName(TName), TVName(TVName))
import           Luna.Pass                    (Pass(Pass), PassMonad, PassCtx)
import qualified Luna.Pass                    as Pass

import qualified Luna.Data.Namespace          as Namespace
import           Luna.Data.Namespace          (Namespace)

import           Luna.Data.ASTInfo            (ASTInfo, genID)

import qualified Luna.Data.Namespace.State    as State 
import qualified Luna.Parser.Parser           as Parser
import qualified Luna.Parser.State            as ParserState
import           Luna.ASTNew.Name.Pattern     (NamePat(NamePat), Segment(Segment), Arg(Arg))
import qualified Luna.ASTNew.Name.Pattern     as NamePat
import           Luna.ASTNew.Name.Hash        (hash)

----------------------------------------------------------------------
-- Base types
----------------------------------------------------------------------

data Hash = Hash

type HPass                 m   = PassMonad () m
type HCtx              lab m a = (Enumerated lab, HTraversal m a)
type HTraversal            m a = (PassCtx m, AST.Traversal        Hash (HPass m) a a)
type HDefaultTraversal     m a = (PassCtx m, AST.DefaultTraversal Hash (HPass m) a a)


------------------------------------------------------------------------
---- Utils functions
------------------------------------------------------------------------

traverseM :: (HTraversal m a) => a -> HPass m a
traverseM = AST.traverseM Hash

defaultTraverseM :: (HDefaultTraversal m a) => a -> HPass m a
defaultTraverseM = AST.defaultTraverseM Hash


------------------------------------------------------------------------
---- Pass functions
------------------------------------------------------------------------

pass :: HDefaultTraversal m a => Pass () (a -> HPass m a)
pass = Pass "Hash" "Hashesh names removing all special characters" () defaultTraverseM

hashDecl :: (HCtx lab m a) => LDecl lab a -> HPass m (LDecl lab a)
hashDecl ast@(Label lab decl) = case decl of
    Decl.Function path sig output body -> return . Label lab
                                        $ Decl.Function path (NamePat.mapSegments hashSegment sig) output body
    _                                  -> continue
    where id       = Enum.id lab
          continue = defaultTraverseM ast

hashSegment = NamePat.mapSegmentBase hash


hashPat :: (MonadIO m, Applicative m, Enumerated lab) => LPat lab -> HPass m (LPat lab)
hashPat ast@(Label lab pat) = case pat of
    Pat.Var name -> return . Label lab . Pat.Var $ fromText $ hash name
    _            -> continue
    where id       = Enum.id lab
          continue = defaultTraverseM ast

----------------------------------------------------------------------
-- Instances
----------------------------------------------------------------------


instance (HCtx lab m a) => AST.Traversal Hash (HPass m) (LDecl lab a) (LDecl lab a) where
    traverseM _ = hashDecl

instance (MonadIO m, Applicative m, Enumerated lab) => AST.Traversal Hash (HPass m) (LPat lab) (LPat lab) where
    traverseM _ = hashPat


