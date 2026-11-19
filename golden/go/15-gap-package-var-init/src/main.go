package main

import (
	"fmt"
	"strings"
)

var greeting = strings.ToUpper("hello")

var config = loadConfig()

var size = len("abc")

func loadConfig() map[string]string {
	return map[string]string{"env": "dev"}
}

func main() {
	fmt.Println(greeting, config, size)
}
