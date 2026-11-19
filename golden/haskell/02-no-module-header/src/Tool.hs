import Data.List (sort)

normalize :: [Int] -> [Int]
normalize xs = sort (reverse xs)

main :: IO ()
main = print (normalize [3, 1, 2])
