module Html (render, frame) where

render :: String -> String
render s = concat ["<p>", s, "</p>"]

frame :: String -> String
frame s = concat ["<div>", s, "</div>"]
