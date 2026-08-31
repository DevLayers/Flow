package root

import (
	"fmt"
	"strconv"

	"github.com/SrwR16/flow-engine/internal/flow"
	"github.com/spf13/cobra"
)

// RecordCmd ingests one executed command into the Flow aggregates store.
// Hidden utility: called by the zsh recorder hook after every command.
// Runs <1ms, writes atomically, safe across concurrent terminals.
var RecordCmd = &cobra.Command{
	Use:    "record",
	Short:  "Record an executed command into Flow aggregates",
	Hidden: true,
	RunE: func(cmd *cobra.Command, args []string) error {
		cmdStr, _ := cmd.Flags().GetString("cmd")
		dir, _ := cmd.Flags().GetString("dir")
		exitStr, _ := cmd.Flags().GetString("exit")
		exit := 0
		if v, err := strconv.Atoi(exitStr); err == nil {
			exit = v
		}
		if cmdStr == "" {
			return nil
		}
		if err := flow.Record(cmdStr, dir, exit); err != nil {
			return fmt.Errorf("flow record: %w", err)
		}
		return nil
	},
}

func init() {
	RecordCmd.Flags().String("cmd", "", "normalized command line")
	RecordCmd.Flags().String("dir", "", "working directory")
	RecordCmd.Flags().String("exit", "0", "exit code")
	_ = RecordCmd.MarkFlagRequired("cmd")

	rootCmd.AddCommand(RecordCmd)
}
