module One where

import Data.Char

loud :: String -> String
loud s = map toUpper s

initial :: String -> Char
initial s = toUpper (head s)
