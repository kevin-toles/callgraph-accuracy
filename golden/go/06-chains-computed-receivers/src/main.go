package main

type Builder struct {
	n int
}

func (b *Builder) Start() *Builder { return b }

func (b *Builder) Next() *Builder {
	b.n++
	return b
}

func (b *Builder) Add(k int) *Builder {
	b.n += k
	return b
}

func (b *Builder) Done() int { return b.n }

func main() {
	var b Builder
	b.Start().
		Next().
		Done()
	b.Add(1).Add(2)
}
