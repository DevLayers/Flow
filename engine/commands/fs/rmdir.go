package fs

import (
	"github.com/SrwR16/flow-engine/spec"
)

func init() {
	spec.Register(&spec.Spec{
		Name:        "rmdir",
		Description: "Remove directories",
		Options: []spec.Option{
			{Name: "-p", Description: "Remove each directory of path"},
		},
	})
}
