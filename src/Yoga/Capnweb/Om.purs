module Yoga.Capnweb.Om
  ( subscribe
  , toSignal
  , rpc0
  , rpc1
  , rpc2
  ) where

import Prelude

import Data.Maybe (Maybe(..))
import Data.Tuple.Nested ((/\))
import Effect (Effect)
import Effect.Aff (forkAff, killFiber)
import Effect.Aff as Aff
import Effect.Aff.AVar (AVar)
import Effect.Aff.AVar as AVar
import Effect.Aff.Class (liftAff)
import Effect.Class (liftEffect)
import Effect.Exception (error)
import Control.Monad.Rec.Class (Step(..))
import Unsafe.Coerce (unsafeCoerce)
import Yoga.Capnweb (RpcConnection, call0, call1, call2, callWithCallback)
import Yoga.Om (Om)
import Yoga.Om.Strom (Strom, mkStrom, bracket)
import Yoga.Om.Strom as Strom

subscribe :: forall ctx err a. String -> RpcConnection -> Strom ctx err a
subscribe method conn = bracket acquire release use
  where
  acquire = liftAff do
    queue <- AVar.empty
    let cb v = Aff.launchAff_ $ AVar.put (unsafeCoerce v :: a) queue
    fiber <- forkAff $ callWithCallback conn method cb
    pure { queue, fiber }

  release res = liftAff do
    killFiber (error "unsubscribed") res.fiber

  use res = pullLoop res.queue

toSignal
  :: forall ctx err a rest
   . { modify :: (Maybe a -> Maybe a) -> Effect Unit | rest }
  -> Strom ctx err a
  -> Om ctx err Unit
toSignal signal = Strom.traverseStrom_ \a ->
  liftEffect $ signal.modify (const (Just a))

pullLoop :: forall ctx err a. AVar a -> Strom ctx err a
pullLoop queue = mkStrom do
  liftAff do
    value <- AVar.take queue
    pure $ Loop (Just [unsafeCoerce value] /\ pullLoop queue)

rpc0 :: forall ctx err a. String -> RpcConnection -> Strom ctx err a
rpc0 method conn = mkStrom do
  result <- liftAff $ call0 conn method
  pure $ Done $ Just [result]

rpc1 :: forall ctx err a b. String -> a -> RpcConnection -> Strom ctx err b
rpc1 method a conn = mkStrom do
  result <- liftAff $ call1 conn method a
  pure $ Done $ Just [result]

rpc2 :: forall ctx err a b c. String -> a -> b -> RpcConnection -> Strom ctx err c
rpc2 method a b conn = mkStrom do
  result <- liftAff $ call2 conn method a b
  pure $ Done $ Just [result]
