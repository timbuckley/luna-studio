{-# LANGUAGE FunctionalDependencies #-}
{-# LANGUAGE UndecidableInstances   #-}

module Luna.Syntax.Builder.Node where

import qualified Control.Monad.Catch      as Catch
import           Control.Monad.Fix
import qualified Control.Monad.State      as State
import           Flowbox.Prelude
import qualified Language.Haskell.Session as HS

-- TODO: template haskellize
-- >->->->->->->->->->->->->->->->->->->->->->->->->->->->->->->->->->->->->->->->->->->->->->->->->->->

newtype NodeBuilderT g m a = NodeBuilderT { fromNodeBuilderT :: State.StateT g m a }
                             deriving (Functor, Monad, Applicative, MonadIO, MonadPlus, MonadTrans, Alternative, MonadFix, HS.GhcMonad, HS.ExceptionMonad, HS.HasDynFlags, Catch.MonadMask, Catch.MonadCatch, Catch.MonadThrow)

type NodeBuilder g = NodeBuilderT g Identity

class Monad m => MonadNodeBuilder g m | m -> g where
    get :: m g
    put :: g -> m ()

instance Monad m => MonadNodeBuilder g (NodeBuilderT g m) where
    get = NodeBuilderT State.get
    put = NodeBuilderT . State.put

instance State.MonadState s m => State.MonadState s (NodeBuilderT g m) where
    get = NodeBuilderT (lift State.get)
    put = NodeBuilderT . lift . State.put

instance {-# OVERLAPPABLE #-} (MonadNodeBuilder g m, MonadTrans t, Monad (t m)) => MonadNodeBuilder g (t m) where
    get = lift get
    put = lift . put

runT  ::            NodeBuilderT g m a -> g -> m (a, g)
evalT :: Monad m => NodeBuilderT g m a -> g -> m a
execT :: Monad m => NodeBuilderT g m a -> g -> m g

runT  = State.runStateT  . fromNodeBuilderT
evalT = State.evalStateT . fromNodeBuilderT
execT = State.execStateT . fromNodeBuilderT


run  :: NodeBuilder g a -> g -> (a, g)
eval :: NodeBuilder g a -> g -> a
exec :: NodeBuilder g a -> g -> g

run   = runIdentity .: runT
eval  = runIdentity .: evalT
exec  = runIdentity .: execT

modified :: MonadNodeBuilder g m => (g -> g) -> m b -> m b
modified f m = do
    s <- get
    put $ f s
    out <- m
    put s
    return out

with :: MonadNodeBuilder g m => g -> m b -> m b
with = modified . const

modify :: MonadNodeBuilder g m => (g -> (g, a)) -> m a
modify f = do
    s <- get
    let (s', a) = f s
    put $ s'
    return a

modify_ :: MonadNodeBuilder g m => (g -> g) -> m ()
modify_ = modify . fmap (,())


-- <-<-<-<-<-<-<-<-<-<-<-<-<-<-<-<-<-<-<-<-<-<-<-<-<-<-<-<-<-<-<-<-<-<-<-<-<-<-<-<-<-<-<-<-<-<-<-<-<-<-<
