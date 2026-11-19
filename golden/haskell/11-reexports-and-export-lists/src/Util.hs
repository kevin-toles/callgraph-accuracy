module Util (slug) where

import qualified Data.Char as C

slug :: String -> String
slug s = map C.toLower (toUpper s)

toUpper :: String -> String
toUpper s = reverse s
