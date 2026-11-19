module App where

import Data.Shape
import qualified Data.Shape as S

summary :: Int -> [Int]
summary r = [area r, S.perimeter r, scaled r]
