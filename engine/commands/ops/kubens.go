package ops

import (
	"github.com/SrwR16/flow-engine/spec"
)

func init() {
	spec.Register(&spec.Spec{
		Name:        "kubens",
		Description: "Switch between Kubernetes-namespaces",
		Options: []spec.Option{
			{Name: "--help", Description: "Show help for kubens"},
			{Name: "--current", Description: "Show current namespace"},
		},
	})
}
