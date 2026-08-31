package sys

import (
	"github.com/SrwR16/flow-engine/spec"
)

func init() {
	spec.Register(&spec.Spec{
		Name:        "trap",
		Description: "Prints all defined signal handlers",
		Options: []spec.Option{
			{Name: "--print", Description: "Prints all defined signal handlers"},
			{Name: "--help", Description: "Displays help about using this command"},
		},
	})
}
