package sys

import (
	"github.com/SrwR16/flow-engine/spec"
)

func init() {
	spec.Register(&spec.Spec{
		Name:        "fmt",
		Description: "Simple text formatter",
		Options: []spec.Option{
			{Name: "-c", Description: "File(s) to format"},
		},
	})
}
