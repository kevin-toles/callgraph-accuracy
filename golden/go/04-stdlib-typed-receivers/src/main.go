package main

import (
	"strings"
	"sync"
)

type Counter struct {
	mu    sync.Mutex
	r     *strings.Reader
	total int
}

func (c *Counter) Add(n int) {
	c.mu.Lock()
	defer c.mu.Unlock()
	c.total += n
}

func (c *Counter) Remaining() int {
	return c.r.Len()
}

func build(parts []string) string {
	var sb strings.Builder
	for _, p := range parts {
		sb.WriteString(p)
	}
	return sb.String()
}

func main() {
	var c Counter
	c.Add(1)
	go c.Add(2)
	_ = c.Remaining()
	_ = build(nil)
}
