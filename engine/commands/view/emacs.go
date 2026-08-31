package view

import (
	"github.com/SrwR16/flow-engine/spec"
)

func init() {
	spec.Register(&spec.Spec{
		Name:        "emacs",
		Description: "An extensible, customizable, free/libre text editor - and more",
		Generator:   spec.FileGenerator(),
	})
}
