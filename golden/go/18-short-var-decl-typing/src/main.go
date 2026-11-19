package main

type Dog struct{}

func NewDog() *Dog { return &Dog{} }

func (d *Dog) Speak() string { return "woof" }

func main() {
	a := &Dog{}
	_ = a.Speak()
	b := NewDog()
	_ = b.Speak()
}
