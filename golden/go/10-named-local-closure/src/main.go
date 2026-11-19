package main

import "fmt"

func double(n int) int { return n * 2 }

func Compute(v int) int {
	f := func(n int) int {
		return double(n) + 1
	}
	return f(v)
}

func main() {
	fmt.Println(Compute(3))
}
