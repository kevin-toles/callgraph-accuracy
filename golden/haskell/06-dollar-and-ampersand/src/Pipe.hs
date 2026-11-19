module Pipe where

import Data.Function ((&))

clean :: String -> String
clean s = reverse s

shout :: String -> String
shout s = map succ s

viaDollar :: String -> String
viaDollar s = shout $ clean s

viaAmp :: String -> String
viaAmp s = s & clean & shout

main :: IO ()
main = putStrLn $ viaDollar "abc"
