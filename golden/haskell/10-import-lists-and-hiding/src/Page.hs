module Page where

import Html hiding (render)
import Plain (render)

page :: String -> String
page s = frame (render s)
