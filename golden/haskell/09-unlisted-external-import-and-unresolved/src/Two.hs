module Two where

import Data.Char
import Data.Maybe

firstDigit :: String -> Bool
firstDigit s = isDigit (head s)

orZero :: Maybe Int -> Int
orZero m = fromMaybe 0 m

mystery :: Int -> Int
mystery n = frobnicate n
