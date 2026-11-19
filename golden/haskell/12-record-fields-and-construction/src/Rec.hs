module Rec where

data Circle = Circle { radius :: Int, label :: String }

mk :: Int -> Circle
mk r = Circle { radius = r, label = show r }

grow :: Circle -> Circle
grow c = c { radius = succ (radius c) }

positional :: Circle
positional = Circle 1 "one"

describe :: Circle -> String
describe c = unwords [label c, show (radius c)]
