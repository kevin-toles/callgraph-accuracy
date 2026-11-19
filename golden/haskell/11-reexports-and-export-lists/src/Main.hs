module Main where

import Shape
import Util
import Data.Char

main :: IO ()
main = do
  print (area 3)
  putStrLn (toUpper (slug "a b"))
