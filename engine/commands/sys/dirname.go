package sys

import (
	"github.com/SrwR16/flow-engine/spec"
)

func init() {
	spec.Register(&spec.Spec{
		Name:        "dirname",
		Description: "Return directory portion of pathname",
	})
}
