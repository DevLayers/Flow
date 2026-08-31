package fs

import (
	"github.com/SrwR16/flow-engine/spec"
)

func init() {
	spec.Register(&spec.Spec{
		Name:        "fold",
		Description: "Fold long lines for finite width output device",
		Options: []spec.Option{
			{Name: "-b", Description: "File(s) to fold"},
		},
	})
}
