package fs

import (
	"github.com/SrwR16/flow-engine/spec"
)

func init() {
	spec.Register(&spec.Spec{
		Name:        "unzip",
		Description: "Extract compressed files in a ZIP archive",
		Options: []spec.Option{
			{Name: "-l", Description: "List the contents of a zip file without extracting"},
		},
	})
}
