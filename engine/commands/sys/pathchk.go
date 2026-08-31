package sys

import (
	"github.com/SrwR16/flow-engine/spec"
)

func init() {
	spec.Register(&spec.Spec{
		Name:        "pathchk",
		Description: "Check pathnames for POSIX portability",
		Options: []spec.Option{
			{Name: "-p", Description: "Pathname(s) to check"},
		},
	})
}
