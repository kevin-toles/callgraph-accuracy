module Hof where

apply :: (a -> b) -> a -> b
apply f x = f x

twice :: (a -> a) -> a -> a
twice g x = g (g x)

withLogger :: (String -> IO ()) -> IO ()
withLogger logger = do
  logger "start"
  mapM_ logger ["a", "b"]

run :: IO ()
run = do
  print (apply negate 3)
  print (twice succ 1)
  withLogger putStrLn
