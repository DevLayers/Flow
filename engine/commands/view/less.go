package view

import (
	"github.com/SrwR16/flow-engine/spec"
)

func init() {
	spec.Register(&spec.Spec{
		Name:        "less",
		Description: "view file contents (scrollable)",
		MaxArgs:     1,
		Generator:   spec.FileGenerator(),
	})
}
