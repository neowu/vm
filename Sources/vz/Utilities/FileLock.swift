import Foundation

class FileLock {
    let fd: Int32

    // url must be file
    init?(_ path: Path) {
        fd = open(path.path, O_WRONLY)
        if fd == -1 {
            return nil
        }
    }

    deinit {
        close(fd)  // close fd will release all locks
    }

    // refer to "man fcntl", once process obtain the lock, it must not reopen fd and close if,
    // close fd will release all locks of current process !!! e.g. lock one file, then read the file / close file
    // https://apenwarr.ca/log/20101213
    func lock() -> Bool {
        var lock = flock(l_start: 0, l_len: 0, l_pid: -1, l_type: Int16(F_WRLCK), l_whence: Int16(SEEK_SET))
        let result = fcntl(fd, F_SETLK, &lock)
        return result == 0  // when result = -1, errno = EAGAIN
    }

    // return pid of write lock owner
    func pid() -> pid_t? {
        var lock = flock(l_start: 0, l_len: 0, l_pid: -1, l_type: Int16(F_RDLCK), l_whence: Int16(SEEK_SET))
        _ = fcntl(fd, F_GETLK, &lock)
        if lock.l_type == F_WRLCK {
            return lock.l_pid
        }
        return nil
    }
}
