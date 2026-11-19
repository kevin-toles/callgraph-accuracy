package broken

import "fmt"

func helper() int { return 1 }

func Run() {
	var n int = "not an int"
	fmt.Println(helper(), n)
	missing(n)
}
