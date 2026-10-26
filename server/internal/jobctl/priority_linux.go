package jobctl

import "syscall"

const (
	ioprioClassIdle  = 3
	ioprioClassShift = 13
	ioprioWhoProcess = 1
)

func Background(nice int) error {
	if err := syscall.Setpriority(syscall.PRIO_PROCESS, 0, nice); err != nil {
		return err
	}
	if _, _, errno := syscall.Syscall(syscall.SYS_IOPRIO_SET, ioprioWhoProcess, 0, ioprioClassIdle<<ioprioClassShift); errno != 0 {
		return errno
	}
	return nil
}
