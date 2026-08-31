package view

import (
	"github.com/SrwR16/flow-engine/spec"
)

func init() {
	spec.Register(&spec.Spec{
		Name:        "cot",
		Description: "Command-line utility for CotEditor",
		Generator:   spec.FileGenerator(),
	})
}
