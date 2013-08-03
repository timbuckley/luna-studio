---------------------------------------------------------------------------
-- Copyright (C) Flowbox, Inc - All Rights Reserved
-- Unauthorized copying of this file, via any medium is strictly prohibited
-- Proprietary and confidential
-- Flowbox Team <contact@flowbox.io>, 2013
---------------------------------------------------------------------------

module Luna.Codegen.Hs.AST.Module (
    Module(..),
    empty,
    base,
    addExpr,
    addExprs,
    addAlias,
    genCode,
    mkInst,
    addDataType,
    addFunction,
    addImport,
    addImports
)where

import           Data.Set                          (Set)
import qualified Data.Set                        as Set

import qualified Luna.Codegen.Hs.Path            as Path
import           Luna.Codegen.Hs.Path              (Path)
import qualified Luna.Codegen.Hs.Import          as Import
import           Luna.Codegen.Hs.Import            (Import)
import qualified Luna.Codegen.Hs.AST.Function    as Function
import           Luna.Codegen.Hs.AST.Function      (Function)
import qualified Luna.Codegen.Hs.AST.DataType    as DataType
import           Luna.Codegen.Hs.AST.DataType      (DataType)
import qualified Luna.Codegen.Hs.AST.Expr        as Expr
import           Luna.Codegen.Hs.AST.Expr          (Expr)
import           Data.String.Utils                 (join)

data Module = Module { path       :: Path
                     , submodules :: [Module]
                     , imports    :: Set Import
                     , datatypes  :: [DataType]
                     , functions  :: [Function]
                     , exprs      :: [Expr]
                     --, datatypes :: [DataType]
                     --, classes   

                        
                     } deriving (Show)

empty :: Module
empty = Module Path.empty [] Set.empty [] [] []

base = empty {imports = Set.singleton $ Import.simple (Path.fromList ["Flowbox", "Core"])}

genCode :: Module -> String
genCode mod =  "module " ++ mypath ++    " where\n\n" 
            ++ "-- imports\n"     ++ imps   ++ "\n\n"
            ++ "-- datatypes\n"   ++ dtypes ++ "\n\n"
            ++ "-- functions\n"   ++ funcs  ++ "\n\n"
            ++ "-- expressions\n" ++ exps  
    where
        mypath = (Path.toModulePath . path) mod
        imps   = join "\n" $ map Import.genCode   (Set.elems $ imports mod)
        dtypes = join "\n" $ map DataType.genCode (datatypes mod)
        funcs  = join "\n" $ map Function.genCode (functions mod)
        exps   = join "\n" $ map Expr.genCode     (exprs mod)



addExpr :: Expr -> Module -> Module
addExpr expr self = self { exprs = expr : exprs self }


addExprs :: [Expr] -> Module -> Module
addExprs exprs self = foldr addExpr self exprs


addAlias :: (String, String) -> Module -> Module
addAlias alias = addExpr (Expr.mkAlias alias)


mkInst :: (String, String, String) -> Module -> Module
mkInst (nameT, nameMT, name) = addExpr (Expr.mkCall "mkInst''" [nameT, nameMT, name])


addDataType :: DataType -> Module -> Module
addDataType dt self = self {datatypes = dt : datatypes self}


addFunction :: Function -> Module -> Module
addFunction func self = self {functions = func : functions self}


addImport :: Import -> Module -> Module
addImport imp self = self {imports = Set.insert imp $ imports self}

addImports :: [Import] -> Module -> Module
addImports imps self = foldr addImport self imps