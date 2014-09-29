---------------------------------------------------------------------------
-- Copyright (C) Flowbox, Inc - All Rights Reserved
-- Unauthorized copying of this file, via any medium is strictly prohibited
-- Proprietary and confidential
-- Flowbox Team <contact@flowbox.io>, 2014
---------------------------------------------------------------------------

module Test.Luna.AST.Control.ZipperSpec where

import Test.Hspec

import           Flowbox.Control.Error
import           Flowbox.Prelude
import qualified Luna.AST.Control.Crumb  as Crumb
import qualified Luna.AST.Control.Focus  as Focus
import qualified Luna.AST.Control.Zipper as Zipper
import           Luna.AST.Module         (Module)
import qualified Test.Luna.AST.Common    as Common
import qualified Test.Luna.SampleCodes   as SampleCodes



main :: IO ()
main = hspec spec


getAST :: IO Module
getAST = Common.getAST SampleCodes.zipperTestModule


spec :: Spec
spec = do
    describe "AST zippers" $ do
        it "focus and defocus on function in module" $ do
            ast <- getAST
            zipper <- eitherToM $ Zipper.focusBreadcrumbs'
                        [ Crumb.Module   "Main"
                        , Crumb.Function "main" []
                        ] ast
            let focus = Zipper.getFocus  zipper
            _ <- Focus.getFunction focus <?.> "Not a function"
            Zipper.close (Zipper.defocus zipper) `shouldBe` ast

        it "focus and defocus on class in module" $ do
            ast    <- getAST
            zipper <- eitherToM $ Zipper.focusBreadcrumbs'
                        [ Crumb.Module   "Main"
                        , Crumb.Class    "Vector"
                        ] ast
            let focus = Zipper.getFocus  zipper
            _ <- Focus.getClass focus <?.> "Not a class"
            Zipper.close (Zipper.defocus zipper) `shouldBe` ast

        it "focus and defocus on class in class in module" $ do
            ast    <- getAST
            zipper <- eitherToM $ Zipper.focusBreadcrumbs'
                        [ Crumb.Module   "Main"
                        , Crumb.Class    "Vector"
                        , Crumb.Class    "Inner"
                        ] ast
            let focus = Zipper.getFocus  zipper
            _ <- Focus.getClass focus <?.> "Not a class"
            Zipper.close (Zipper.defocus zipper) `shouldBe` ast

        it "focus and defocus on function in class in module" $ do
            ast    <- getAST
            zipper <- eitherToM $ Zipper.focusBreadcrumbs'
                        [ Crumb.Module   "Main"
                        , Crumb.Class    "Vector"
                        , Crumb.Function "test" []
                        ] ast
            let focus = Zipper.getFocus  zipper
            _ <- Focus.getFunction focus <?.> "Not a function"
            Zipper.close (Zipper.defocus zipper) `shouldBe` ast

        it "focus and defocus on function in class in class in module" $ do
            ast    <- getAST
            zipper <- eitherToM $ Zipper.focusBreadcrumbs'
                        [ Crumb.Module   "Main"
                        , Crumb.Class    "Vector"
                        , Crumb.Class    "Inner"
                        , Crumb.Function "inner" []
                        ] ast
            let focus = Zipper.getFocus  zipper
            _ <- Focus.getFunction focus <?.> "Not a function"
            Zipper.close (Zipper.defocus zipper) `shouldBe` ast

        it "focus and defocus on lambda in function in class in module" $ do
            ast    <- getAST
            zipper <- eitherToM $ Zipper.focusBreadcrumbs'
                        [ Crumb.Module   "Main"
                        , Crumb.Class    "Vector"
                        , Crumb.Function "test" []
                        , Crumb.Lambda   27
                        ] ast
            let focus = Zipper.getFocus  zipper
            l <- Focus.getLambda focus <?.> "Not a lambda"
            print l
            Zipper.close (Zipper.defocus zipper) `shouldBe` ast
