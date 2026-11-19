module Data.Shape (area, perimeter, scaled) where

area :: Int -> Int
area r = product [3, r, r]

perimeter :: Int -> Int
perimeter r = product [6, r]

scaled :: Int -> Int
scaled r = area (succ r)
