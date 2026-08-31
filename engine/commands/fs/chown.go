package fs

import (
	"github.com/SrwR16/flow-engine/spec"
)

func init() {
	spec.Register(&spec.Spec{
		Name:        "chown",
		Description: "change file owner",
		Generator:   spec.FileGenerator(),
		Options: []spec.Option{
			{Name: "-R", Description: "recursive"},
		},
	})
}
