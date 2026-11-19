module Index where

import qualified Data.Map as Map
import qualified Data.Set

build :: [(String, Int)] -> Int
build kvs = Map.size (Map.fromList kvs)

uniq :: [Int] -> Int
uniq xs = Data.Set.size (Data.Set.fromList xs)
