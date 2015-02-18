module Flowbox.Graphics.Mockup.GeneratorSpec where

import Test.Hspec
import Test.QuickCheck
import System.IO.Unsafe

import Flowbox.Graphics.Mockup.Generator
import Flowbox.Graphics.Mockup.Basic
import Flowbox.Prelude
import Flowbox.Graphics.Color.Color

import TestHelpers


spec :: Spec
spec = do
	let specPath = "./test/Flowbox/Graphics/Mockup/"
		in do 
		  	let testName = "constantLuna"
			let testPath = specPath++testName

			describe testName $ do
				describe "should match reference image" $ do
					let actualImage = constantLuna PCVideo (RGBA 0.3 0.4 0.5 0.6)
					let	expectedImage = getDefaultTestPic specPath testName
					it "in pixel-wise metric" $ do
						 shouldBeCloseTo testPath PixelWise actualImage (unsafePerformIO expectedImage)
					it "in image-wise metric" $ do
						 shouldBeCloseTo testPath ImageWise actualImage (unsafePerformIO expectedImage)
					it "in size-wise metric" $ do
						 shouldBeCloseTo testPath SizeWise actualImage (unsafePerformIO expectedImage)

			do
				let testName = "conicalLuna"
				let testPath = specPath++testName

				describe testName $ do
					let actualImage = conicalLuna 100 120
					let	expectedImage = getDefaultTestPic specPath testName
					--it "should save img" $ do
					--	testSave actualImage `shouldReturn` ()
					describe "should match reference image" $ do
						it "in pixel-wise metric" $ do
							shouldBeCloseTo testPath PixelWise actualImage (unsafePerformIO expectedImage)
						




testSave image = do
    saveImageLuna "./test/samples/x_result.png" image
    return ()