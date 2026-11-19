package main

import "fmt"

type Celsius float64

type Point struct{ X, Y int }

type Dog struct{}

func (d Dog) Bark() string { return "woof" }

func double(n int) int { return n * 2 }

func apply(f func(int) int, v int) int { return f(v) }

func main() {
	xs := make([]int, 0, 4)
	xs = append(xs, len("ab"), cap(xs))
	m := map[string]int{}
	delete(m, "k")
	t := Celsius(3.5)
	b := []byte("hi")
	p := Point{X: 1, Y: 2}
	q := new(Point)
	var d Dog
	bark := d.Bark
	fmt.Println(xs, t, b, p.X, q, apply(double, 3), bark())
	if len(xs) > 10 {
		panic("too many")
	}
}
