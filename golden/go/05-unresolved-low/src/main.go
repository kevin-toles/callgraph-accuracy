package main

import (
	"fmt"
	"strings"
	"time"
)

func main() {
	r := strings.NewReader("abc")
	fmt.Println(r.Len())
	fmt.Println(time.Now().Unix())
	fmt.Println(strings.NewReader("x").Size())
}
