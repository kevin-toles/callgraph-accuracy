module Lam where

data Point = Point Int Int

labels :: [Int] -> [String]
labels xs = map (\x -> show (abs x)) xs

origin :: Point
origin = Point 0 0

shift :: [Int] -> [Int]
shift = map succ

pairs :: [Int] -> [(Int, String)]
pairs xs = zip xs (labels xs)

render :: Point -> String
render (Point x y) = unwords (map show [x, y])
