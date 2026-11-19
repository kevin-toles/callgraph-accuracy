module Use where

import Rec (Circle (..))

size :: Circle -> Int
size c = negate (radius c)
