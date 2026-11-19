package main

import (
	"fmt"
	"sort"
)

func key(s string) int { return len(s) }

func SortByLen(xs []string) {
	sort.Slice(xs, func(i, j int) bool {
		return key(xs[i]) < key(xs[j])
	})
	sort.SliceStable(xs, func(i, j int) bool {
		return fmt.Sprint(xs[i]) < xs[j]
	})
}

func main() {
	words := []string{"ccc", "a", "bb"}
	SortByLen(words)
	fmt.Println(words)
}
