package main

type Base struct{}

func (b Base) Hello() string { return "hello" }

func (b Base) ID() int { return 1 }

type Derived struct {
	Base
}

func (d Derived) ID() int { return 2 }

func run(d Derived) {
	_ = d.Hello()
	_ = d.ID()
	_ = d.Base.ID()
}

func main() {
	var d Derived
	run(d)
}
