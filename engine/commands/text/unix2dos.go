package text

import (
	"github.com/SrwR16/flow-engine/spec"
)

func init() {
	spec.Register(&spec.Spec{
		Name:        "unix2dos",
		Description: "Unix to DOS text file format convertor",
	})
}
