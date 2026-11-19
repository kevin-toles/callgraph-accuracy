package main

import "example.com/m/store"

func main() {
	var c store.Cache
	store.Fill(&c, []string{" a "})
	c.Put(store.Normalize(" b "))
}
