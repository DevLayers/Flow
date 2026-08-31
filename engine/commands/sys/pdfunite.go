package sys

import (
	"github.com/SrwR16/flow-engine/spec"
)

func init() {
	spec.Register(&spec.Spec{
		Name:        "pdfunite",
		Description: "Combine multiple pdfs",
		Options: []spec.Option{
			{Name: "-v", Description: "Print copyright and version info"},
			{Name: "-h", Description: "Print usage information"},
		},
	})
}
