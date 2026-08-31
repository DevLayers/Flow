package sys

import (
	"github.com/SrwR16/flow-engine/spec"
)

func init() {
	spec.Register(&spec.Spec{
		Name:        "exec",
		Description: "Replace the current shell with a program",
	})
}
