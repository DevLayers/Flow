package js

import (
	"github.com/SrwR16/flow-engine/spec"
)

func init() {
	spec.Register(&spec.Spec{
		Name:        "create-vite",
		Description: "Create a new project powered by Vite",
	})
}
