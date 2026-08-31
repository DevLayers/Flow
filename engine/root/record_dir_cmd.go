package root

import (
	"github.com/SrwR16/flow-engine/internal/flow"
	"github.com/spf13/cobra"
)

var RecordDirCmd = &cobra.Command{
	Use:    "record-dir",
	Short:  "Record a directory visit",
	Hidden: true,
	RunE: func(cmd *cobra.Command, args []string) error {
		dir, _ := cmd.Flags().GetString("dir")
		if dir == "" {
			return nil
		}
		flow.RecordDirVisit(dir)
		return nil
	},
}

func init() {
	RecordDirCmd.Flags().String("dir", "", "directory path")
	_ = RecordDirCmd.MarkFlagRequired("dir")
	rootCmd.AddCommand(RecordDirCmd)
}
