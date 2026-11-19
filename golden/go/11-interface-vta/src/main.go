package main

import "fmt"

type Animal interface {
	Speak() string
}

type Dog struct{}

func (d *Dog) Speak() string { return "woof" }

type Cat struct{}

func (c Cat) Speak() string { return "meow" }

type Fish struct{}

func (f Fish) Speak() string { return "..." }

func describe(a Animal) string {
	return a.Speak()
}

func main() {
	fmt.Println(describe(&Dog{}))
	fmt.Println(describe(Cat{}))
	var f Fish
	fmt.Println(f.Speak())
}
