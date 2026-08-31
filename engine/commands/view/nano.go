package view

import (
	"github.com/SrwR16/flow-engine/spec"
)

func init() {
	spec.Register(&spec.Spec{
		Name:        "nano",
		Description: "Nano",
		Generator:   spec.FileGenerator(),
	})
}
