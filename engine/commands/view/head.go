package view

import (
	"github.com/SrwR16/flow-engine/spec"
)

func init() {
	spec.Register(&spec.Spec{
		Name:        "head",
		Description: "output first lines of file",
		Generator:   spec.FileGenerator(),
		Options: []spec.Option{
			{Name: "-n", Description: "number of lines"},
		},
	})
}
