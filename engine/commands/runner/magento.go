package runner

import (
	"github.com/SrwR16/flow-engine/spec"
)

func init() {
	spec.Register(&spec.Spec{
		Name:        "magento",
		Description: "Open-source E-commerce",
	})
}
