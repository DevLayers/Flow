package js

import (
	"github.com/SrwR16/flow-engine/spec"
)

func init() {
	spec.Register(&spec.Spec{
		Name:        "dotenv",
		Description: "Loads environment variables from .env",
		Options: []spec.Option{
			{Name: "-f", Description: "List of env files to parse"},
			{Name: "-h", Description: "Display help"},
			{Name: "-v", Description: "Show version"},
			{Name: "-t", Description: "Create a template env file"},
		},
	})
}
