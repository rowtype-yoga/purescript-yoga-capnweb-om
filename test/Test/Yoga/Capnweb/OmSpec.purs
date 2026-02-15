module Test.Yoga.Capnweb.OmSpec where

import Prelude

import Control.Promise (Promise, toAff)
import Effect.Aff (Aff)
import Data.Array as Array
import Data.Either (Either(..))
import Effect (Effect)
import Effect.Class (liftEffect)
import Effect.Exception (throwException, error)
import Test.Spec (Spec, describe, it)
import Test.Spec.Assertions (shouldEqual)
import Yoga.Capnweb (connectPair)
import Yoga.Capnweb.Om as Capnweb
import Yoga.Capnweb.Server (RpcTarget)
import Yoga.Om as Om
import Yoga.Om.Strom as Strom

foreign import mkTestTarget :: Effect RpcTarget

foreign import delayMs :: Int -> Promise Unit

type PushItem = { index :: Int, value :: String }

runOm :: forall a. Om.Om {} () a -> Aff a
runOm om = do
  result <- Om.runReader {} om
  case result of
    Right a -> pure a
    Left _ -> liftEffect $ throwException (error "Om error")

spec :: Spec Unit
spec = describe "Yoga.Capnweb.Om" do
  describe "rpc" do
    it "rpc1 returns a single value" do
      target <- liftEffect mkTestTarget
      conn <- liftEffect $ connectPair target
      result <- runOm $ Strom.runCollect $ Capnweb.rpc1 "ping" "hello" conn
      result `shouldEqual` ["pong: hello"]

    it "rpc2 passes two arguments" do
      target <- liftEffect mkTestTarget
      conn <- liftEffect $ connectPair target
      result <- runOm $ Strom.runCollect $ Capnweb.rpc2 "add" 3 4 conn
      result `shouldEqual` [7]

  describe "subscribe" do
    it "receives pushed values" do
      target <- liftEffect mkTestTarget
      conn <- liftEffect $ connectPair target
      items :: Array PushItem <- runOm $ Strom.runCollect $
        Capnweb.subscribe "pushItems" conn
          # Strom.takeStrom 5
      Array.length items `shouldEqual` 5

    it "cleans up when taking fewer than pushed" do
      target <- liftEffect mkTestTarget
      conn <- liftEffect $ connectPair target
      items :: Array PushItem <- runOm $ Strom.runCollect $
        Capnweb.subscribe "pushItems" conn
          # Strom.takeStrom 2
      Array.length items `shouldEqual` 2
