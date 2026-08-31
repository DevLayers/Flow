package sys

import (
	"github.com/SrwR16/flow-engine/spec"
)

func init() {
	spec.Register(&spec.Spec{
		Name:        "eleventy",
		Description: "Eleventy is a simpler static site generator",
	})
}
