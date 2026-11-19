module Shapes (Shape (..), Square (..)) where

class Shape a where
  area :: a -> Int
  name :: a -> String

newtype Square = Square Int

instance Shape Square where
  area (Square s) = product [s, s]
  name _ = "square"
