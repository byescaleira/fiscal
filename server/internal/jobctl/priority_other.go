//go:build unix && !linux

package jobctl

import "syscall"

func Background(nice int) error {
	return syscall.Setpriority(syscall.PRIO_PROCESS, 0, nice)
}
