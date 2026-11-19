module Infix where

combine :: Int -> Int -> Int
combine a b = max a b

halve :: Int -> Int
halve n = n `div` 2

merged :: Int -> Int -> Int
merged x y = x `combine` y

nested :: Int -> Int
nested n = (n `combine` 1) `combine` halve n
