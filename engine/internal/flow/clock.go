package flow

import "time"

// timeNowUnix is a variable so tests can pin the clock.
var timeNowUnix = func() int64 { return time.Now().Unix() }
