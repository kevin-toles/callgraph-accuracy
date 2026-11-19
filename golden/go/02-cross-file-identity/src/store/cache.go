package store

import "strings"

type Cache struct {
	data map[string]bool
}

func Normalize(k string) string {
	return strings.TrimSpace(k)
}

func (c *Cache) Put(k string) {
	c.data[Normalize(k)] = true
}
