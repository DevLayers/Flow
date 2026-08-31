package js

import (
	"github.com/SrwR16/flow-engine/spec"
)

func init() {
	spec.Register(&spec.Spec{
		Name:        "create-video",
		Description: "CLI used to create remotion video project",
	})
}
