package main

import (
	"fmt"
	"path/filepath"

	u "example.com/m/util"
)

func greet(name string) string {
	return fmt.Sprintf("hi %s", name)
}

func main() {
	msg := greet("bob")
	fmt.Println(msg)
	fmt.Println(filepath.Base("/a/b.txt"))
	fmt.Println(u.Shout(msg))
}
