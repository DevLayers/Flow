package js

import (
	"github.com/SrwR16/flow-engine/spec"
)

func init() {
	spec.Register(&spec.Spec{
		Name:        "create-remix",
		Description: "Display help for command",
		Options: []spec.Option{
			{Name: "-h", Description: "Display help for command"},
			{Name: "-v", Description: "Display version for command"},
		},
	})
}
