module Doc where

class Pretty a where
  pretty :: a -> String
  prettyAll :: [a] -> String
  prettyAll xs = unwords (map pretty xs)

data Color = Red | Green

instance Pretty Color where
  pretty Red = "red"
  pretty Green = reverse "neerg"

newtype Box = Box Int

instance Show Box where
  show (Box n) = unwords ["Box", show n]

shout :: Color -> String
shout c = concat [pretty c, prettyAll [c, c], show (Box 2)]
