module Geo.Calc where

double :: Int -> Int
double n = sum [n, n]

describe :: Int -> String
describe n = unwords ["value", show (double n)]

report :: [Int] -> String
report xs =
  concat
    (map
       describe
       (reverse xs))

banner :: String
banner = replicate 3 'x'

main :: IO ()
main = do
  putStrLn (describe 4)
  print (length (report [1, 2]))
