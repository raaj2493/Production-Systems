package main

import (
	"os"

	"edith-engine/internal/cli"
)

func main() {
	os.Exit(cli.Run(os.Args[1:]))
}
