package fs

import (
	"github.com/SrwR16/flow-engine/spec"
)

func init() {
	spec.Register(&spec.Spec{
		Name:        "touch",
		Description: "create or update file timestamp",
		Generator:   spec.FileGenerator(),
	})
}
