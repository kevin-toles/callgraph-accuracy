package main

import "fmt"

type Namer interface {
	Name() string
}

func Label[T Namer](x T) string {
	return "<" + x.Name() + ">"
}

func Show[T fmt.Stringer](x T) string {
	return x.String()
}

func main() {}
