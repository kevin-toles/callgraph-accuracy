module Text.Fmt (render) where

render :: [String] -> String
render items = wrap (joinAll items)
  where
    joinAll xs = unwords (map clean xs)
      where
        clean s = reverse (trim s)
        trim s = dropWhile isSpace' s
    wrap s = concat ["[", s, "]"]

isSpace' :: Char -> Bool
isSpace' c = elem c " \t"

main :: IO ()
main = do
  let shout s = map succ s
  putStrLn (shout (render ["a", "b"]))
