package flow

import (
	"bufio"
	"os"
)

func bufioScanner(f *os.File) *bufio.Scanner {
	sc := bufio.NewScanner(f)
	sc.Buffer(make([]byte, 0, 64*1024), 1024*1024)
	return sc
}

func openWrite(path string) *os.File {
	f, err := os.Create(path)
	if err != nil {
		return nil
	}
	return f
}

func e_fail(fields []string) int {
	if len(fields) >= 5 {
		return sanitizeInt(fields[4])
	}
	return 0
}
