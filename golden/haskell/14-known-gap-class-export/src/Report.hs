module Report where

import Shapes

line :: Square -> String
line sq = unwords [name sq, show (area sq)]
