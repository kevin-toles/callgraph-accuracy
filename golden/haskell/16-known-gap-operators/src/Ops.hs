module Ops where

(<+>) :: [Int] -> [Int] -> [Int]
a <+> b = concat [a, b]

total :: [Int] -> Int
total xs = sum xs + length ([1] <+> xs)

bumped :: [Int] -> [Int]
bumped xs = map (+ 1) xs
