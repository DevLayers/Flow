package root

import (
	"os"
	"testing"

	"github.com/SrwR16/flow-engine/internal/scoring"
	"go.uber.org/goleak"
)

func TestMain(m *testing.M) {
	code := m.Run()
	scoring.CloseGlobalFrecencyStore()
	if code == 0 {
		if err := goleak.Find(); err != nil {
			_, _ = os.Stderr.WriteString("goleak: " + err.Error() + "\n")
			os.Exit(1)
		}
	}
	os.Exit(code)
}
