package view

import (
	"github.com/SrwR16/flow-engine/spec"
)

func init() {
	spec.Register(&spec.Spec{
		Name:        "file",
		Description: "determine file type",
		Generator:   spec.FileGenerator(),
	})
}
