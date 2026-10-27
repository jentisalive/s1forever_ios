#pragma once
#include <array>
#include <cerrno>
#include <cstdint>
#include <functional>
#include <fcntl.h>
#include <sys/stat.h>
#include <unistd.h>

namespace forever {
// Copy only to a new staging file; the caller validates it before replacing game data.
inline int CopyFileWithProgress(const char *source, const char *staging,
                               const std::function<void(uint64_t, uint64_t)> &progress) {
    struct File {
        int fd;
        ~File() { if (fd >= 0) close(fd); }
    };
    File input{open(source, O_RDONLY)};
    if (input.fd < 0) return errno;
    struct stat info{};
    if (fstat(input.fd, &info) != 0) return errno;
    if (!S_ISREG(info.st_mode) || info.st_size <= 0) return EINVAL;
    File output{open(staging, O_WRONLY | O_CREAT | O_EXCL, 0600)};
    if (output.fd < 0) return errno;
    const auto total = static_cast<uint64_t>(info.st_size);
    uint64_t copied = 0;
    std::array<unsigned char, 256 * 1024> buffer;
    progress(0, total);
    for (;;) {
        ssize_t count = read(input.fd, buffer.data(), buffer.size());
        if (count < 0) { if (errno == EINTR) continue; return errno; }
        if (count == 0) break;
        ssize_t written = 0;
        while (written < count) {
            ssize_t amount = write(output.fd, buffer.data() + written, count - written);
            if (amount < 0) { if (errno == EINTR) continue; return errno; }
            if (amount == 0) return EIO;
            written += amount;
        }
        copied += static_cast<uint64_t>(count);
        if (copied > total) return EIO;
        progress(copied, total);
    }
    if (copied != total) return EIO;
    if (fsync(output.fd) != 0) return errno;
    int fd = output.fd;
    output.fd = -1;
    return close(fd) == 0 ? 0 : errno;
}
}
