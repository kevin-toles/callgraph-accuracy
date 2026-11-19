package main

import (
	"fmt"
	"iter"
)

func Count(n int) iter.Seq[int] {
	return func(yield func(int) bool) {
		for i := 0; i < n; i++ {
			if !yield(i) {
				return
			}
		}
	}
}

func process(i int) {}

func Sum(seq iter.Seq[int]) {
	for x := range seq {
		process(x)
	}
	for y := range Count(3) {
		fmt.Println(y)
	}
}

func main() {}
