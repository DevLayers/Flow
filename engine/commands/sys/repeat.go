package sys

import (
	"github.com/SrwR16/flow-engine/spec"
)

func init() {
	spec.Register(&spec.Spec{
		Name:        "repeat",
		Description: "Interpret the result as a number and repeat the commands this many times",
	})
}
