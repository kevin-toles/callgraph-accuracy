package main

import "fmt"

type Stack[T any] struct {
	items []T
}

func (s *Stack[T]) Push(v T) {
	s.items = append(s.items, v)
	s.log("push")
}

func (s *Stack[T]) log(op string) {
	fmt.Println(op, len(s.items))
}

func Map[T, U any](xs []T, f func(T) U) []U {
	out := make([]U, 0, len(xs))
	for _, x := range xs {
		out = append(out, f(x))
	}
	return out
}

func itoa(n int) string { return fmt.Sprint(n) }

func main() {
	var s Stack[int]
	s.Push(1)
	names := Map[int, string]([]int{1, 2}, itoa)
	fmt.Println(Map(names, func(v string) int { return len(v) }))
}
