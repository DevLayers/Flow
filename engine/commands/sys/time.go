package sys

import (
	"github.com/SrwR16/flow-engine/spec"
)

func init() {
	spec.Register(&spec.Spec{
		Name:        "time",
		Description: "Time how long a command takes!",
	})
}
