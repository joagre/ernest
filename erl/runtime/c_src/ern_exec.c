/*
 * ern_exec: runs one program for Os.start (report Appendix E.23), doing what
 * the host's ports cannot: the program's standard error apart from its
 * output, the end of its input while its output is still read, and a kill
 * of the program with its process group. It is C99 over POSIX.1-2008 alone,
 * so that any POSIX host builds it; Ernest runs on Linux and macOS.
 *
 * Run with the argument `run`, the helper runs the program the runtime's
 * first frame names. The runtime and this helper talk over fd 0 and fd 1 in
 * frames of a 4-byte big-endian length followed by a tag byte and the
 * frame's data.
 *
 *   To the program: first 'c', the program and then each of its arguments,
 *   each ended by a NUL byte, as execvp takes them; they come here and not
 *   on the helper's own command line, so that an argument too long for the
 *   host is the program's failure to start, and not the helper's. Then 'i'
 *   bytes of its input, dropped after 'e' or once the
 *   program has closed its input; 'e' the end of its input; 'n' a request
 *   for the next piece of its output. The end of fd 0 means the runtime has
 *   let go of the run: the program and its process group are killed, and
 *   the helper ends.
 *
 *   From the program: 's' it started; 'f' and an error's name, it did not
 *   start; 'a' the program has taken the bytes of one 'i', or 'd' they
 *   were dropped, one of the two for each 'i' in order, so that a writer
 *   waits while the program is behind and learns whether its bytes were
 *   taken; 'o' bytes of its output; 'r' bytes of its standard
 *   error, each answering one 'n', so that a program no one asks waits on
 *   its output;
 *   'x' and a 4-byte big-endian status, once it has exited and both its
 *   output and its standard error have ended. A status is the program's
 *   exit code, or 128 and the signal's number for a program a signal ended.
 *
 * With no argument, the helper writes its environment, which it inherited
 * as exec passes it, byte for byte: a 'v' frame for each variable, NAME=VALUE,
 * and an 'x' frame. Report Appendix E.23: the runtime reads the program's
 * environment so, since the host decodes a value that is not UTF-8 without
 * a sign.
 *
 * Run with the argument `remove`, the helper removes the path the runtime's
 * first frame names, 'p' and the path's bytes, a directory with everything
 * under it, and answers 'd' once it is gone, or 'f' and the name of the
 * error that stopped it. Report Appendix E.17: it walks a directory by the
 * directories it has opened, never by a path, which the host's file module
 * cannot do.
 */
#define _POSIX_C_SOURCE 200809L
#include <dirent.h>
#include <errno.h>
#include <fcntl.h>
#include <poll.h>
#include <signal.h>
#include <stdint.h>
#include <stdlib.h>
#include <string.h>
#include <sys/types.h>
#include <sys/wait.h>
#include <unistd.h>

#define CHUNK 65536

extern char **environ;

static pid_t program = -1;

/* The command the runtime's first frame names: the frame's text, and the
   program and its arguments pointing into it, as execvp takes them, held
   here so that they stay reachable until the helper ends. */
static char *command_text = NULL;
static char **command = NULL;

/* The program and every process of its group, killed and reaped. */
static void kill_program(void)
{
    if (program > 0) {
        kill(-program, SIGKILL);
        kill(program, SIGKILL);
        while (waitpid(program, NULL, 0) < 0 && errno == EINTR)
            ;
    }
}

static void write_all(int fd, const unsigned char *data, size_t size)
{
    while (size > 0) {
        ssize_t written = write(fd, data, size);
        if (written < 0 && errno == EINTR)
            continue;
        if (written <= 0) {
            /* the runtime is gone: nothing is left to answer */
            kill_program();
            _exit(1);
        }
        data += written;
        size -= (size_t)written;
    }
}

static void frame(unsigned char tag, const unsigned char *data, size_t size)
{
    uint32_t length = (uint32_t)size + 1;
    unsigned char head[5] = {
        (unsigned char)(length >> 24), (unsigned char)(length >> 16),
        (unsigned char)(length >> 8), (unsigned char)length, tag
    };
    write_all(1, head, sizeof head);
    write_all(1, data, size);
}

static const char *error_name(int error)
{
    switch (error) {
    case ENOENT: return "enoent";
    case ENOTDIR: return "enotdir";
    case EACCES: return "eacces";
    case EPERM: return "eperm";
    default: return strerror(error);
    }
}

/* The program did not start: the host's reason, in an 'f' frame, which ends
   the helper's work (report Appendix E.23: start answers the host's
   reason). */
static int not_started(int error)
{
    const char *name = error_name(error);
    frame('f', (const unsigned char *)name, strlen(name));
    return 0;
}

/* The input not yet written to the program: pending_size bytes from
   pending_start in a buffer that grows. A write takes bytes from the front
   by moving the start; the unwritten bytes move to the buffer's front only
   when an input does not fit after them, into a buffer at least twice
   their size, so each byte moves a bounded number of times however little
   the program takes at once. */
static unsigned char *pending = NULL;
static size_t pending_start = 0, pending_size = 0, pending_capacity = 0;

/* The end of each 'i' not yet answered, as a count of the input's bytes
   from its start, oldest first, and whether it was dropped, given after
   the end of the input; taken is how many the program has taken, accepted
   how many were given. */
struct end {
    uint64_t offset;
    int dropped;
};
static struct end *ends = NULL;
static size_t ends_count = 0, ends_capacity = 0;
static uint64_t accepted = 0, taken = 0;

static void push_end(uint64_t offset, int dropped)
{
    if (ends_count == ends_capacity) {
        size_t capacity = ends_capacity ? 2 * ends_capacity : 64;
        struct end *grown = realloc(ends, capacity * sizeof *ends);
        if (grown == NULL) {
            kill_program();
            _exit(1);
        }
        ends = grown;
        ends_capacity = capacity;
    }
    ends[ends_count].offset = offset;
    ends[ends_count].dropped = dropped;
    ends_count++;
}

/* An 'a' for every 'i' whose bytes the program has taken, a 'd' for every
   'i' given after the end of its input once the input before it is taken,
   and, where its input is gone, a 'd' for every other 'i' still waiting. */
static void acknowledge(int gone)
{
    size_t answered = 0;
    while (answered < ends_count && (gone || ends[answered].offset <= taken)) {
        frame(ends[answered].offset <= taken && !ends[answered].dropped ? 'a' : 'd', NULL, 0);
        answered++;
    }
    if (answered > 0) {
        memmove(ends, ends + answered, (ends_count - answered) * sizeof *ends);
        ends_count -= answered;
    }
}

static void add_pending(const unsigned char *data, size_t size)
{
    /* nothing to add, and before the first input no buffer to add it to */
    if (size == 0)
        return;
    if (pending_start + pending_size + size > pending_capacity) {
        size_t capacity = pending_capacity ? pending_capacity : CHUNK;
        while (capacity < 2 * (pending_size + size))
            capacity *= 2;
        if (capacity != pending_capacity) {
            unsigned char *grown = realloc(pending, capacity);
            if (grown == NULL) {
                kill_program();
                _exit(1);
            }
            pending = grown;
            pending_capacity = capacity;
        }
        memmove(pending, pending + pending_start, pending_size);
        pending_start = 0;
    }
    memcpy(pending + pending_start + pending_size, data, size);
    pending_size += size;
}

/* Size bytes from the runtime into data: 0 where the runtime let go
   first. */
static int read_all(unsigned char *data, size_t size)
{
    while (size > 0) {
        ssize_t received = read(0, data, size);
        if (received < 0 && errno == EINTR)
            continue;
        if (received <= 0)
            return 0;
        data += received;
        size -= (size_t)received;
    }
    return 1;
}

/* The runtime's first frame, the command, 'c' and at least the program,
   each part ended by a NUL byte, as execvp takes it; NULL where it is not
   one. */
static char **read_command(void)
{
    unsigned char head[4];
    size_t length, at, parts = 0, part;

    if (!read_all(head, sizeof head))
        return NULL;
    length = (size_t)head[0] << 24 | (size_t)head[1] << 16 | (size_t)head[2] << 8 | head[3];
    if (length < 3)
        return NULL;
    command_text = malloc(length);
    if (command_text == NULL || !read_all((unsigned char *)command_text, length)
        || command_text[0] != 'c' || command_text[length - 1] != '\0')
        return NULL;
    for (at = 1; at < length; at++)
        if (command_text[at] == '\0')
            parts++;
    command = malloc((parts + 1) * sizeof *command);
    if (command == NULL)
        return NULL;
    for (at = 1, part = 0; part < parts; part++) {
        command[part] = command_text + at;
        at += strlen(command_text + at) + 1;
    }
    command[parts] = NULL;
    return command;
}

/*
 * Report Appendix E.17: Fs.removeAll. Each entry is opened relative to its
 * directory, refusing a link, and removed relative to it, so that a
 * directory another process replaces with a link while the walk runs leads
 * it nowhere else, and a link is removed, never followed.
 */

/* The name Erlang gives an error, which the runtime describes as it does
   the file system's other errors; the host's own words where Erlang has no
   name for it. */
static const char *posix_name(int error)
{
    switch (error) {
    case ENOENT: return "enoent";
    case ENOTDIR: return "enotdir";
    case EACCES: return "eacces";
    case EPERM: return "eperm";
    case ENOTEMPTY: return "enotempty";
    case EISDIR: return "eisdir";
    case EBUSY: return "ebusy";
    case EROFS: return "erofs";
    case ELOOP: return "eloop";
    case EIO: return "eio";
    case ENAMETOOLONG: return "enametoolong";
    case EMFILE: return "emfile";
    case ENFILE: return "enfile";
    case ENOMEM: return "enomem";
    default: return strerror(error);
    }
}

/* The flags that open a directory and nothing else: a link is refused
   with ELOOP and any other file with ENOTDIR, and a named pipe is not
   waited on. */
#define DIRECTORY_ONLY (O_RDONLY | O_DIRECTORY | O_NOFOLLOW | O_NONBLOCK | O_CLOEXEC)

/* The names in the directory open as directory, "." and ".." left out,
   read whole before any is removed; NULL with errno set where they cannot
   be read. */
static char **entry_names(int directory, size_t *count)
{
    int listing = dup(directory);
    DIR *stream;
    struct dirent *entry;
    char **names = malloc(sizeof *names);
    size_t capacity = 1;
    int error;

    *count = 0;
    if (names == NULL || listing < 0) {
        error = listing < 0 ? errno : ENOMEM;
        if (listing >= 0)
            close(listing);
        free(names);
        errno = error;
        return NULL;
    }
    stream = fdopendir(listing);
    if (stream == NULL) {
        error = errno;
        close(listing);
        free(names);
        errno = error;
        return NULL;
    }
    for (;;) {
        errno = 0;
        entry = readdir(stream);
        if (entry == NULL)
            break;
        if (strcmp(entry->d_name, ".") == 0 || strcmp(entry->d_name, "..") == 0)
            continue;
        if (*count == capacity) {
            char **grown = realloc(names, 2 * capacity * sizeof *names);
            if (grown == NULL) {
                errno = ENOMEM;
                break;
            }
            names = grown;
            capacity *= 2;
        }
        names[*count] = strdup(entry->d_name);
        if (names[*count] == NULL) {
            errno = ENOMEM;
            break;
        }
        (*count)++;
    }
    error = errno;
    closedir(stream);
    if (error != 0) {
        while (*count > 0)
            free(names[--*count]);
        free(names);
        errno = error;
        return NULL;
    }
    return names;
}

static int remove_entry(int directory, const char *name);

/* Everything in the directory open as directory removed: 0, or the error
   of the first removal that failed. */
static int empty_directory(int directory)
{
    size_t count, at;
    int error = 0;
    char **names = entry_names(directory, &count);

    if (names == NULL)
        return errno;
    for (at = 0; at < count; at++) {
        if (error == 0)
            error = remove_entry(directory, names[at]);
        free(names[at]);
    }
    free(names);
    return error;
}

/* The entry of the directory open as directory removed: a directory with
   everything under it, and anything else, a link among them, as itself. */
static int remove_entry(int directory, const char *name)
{
    int inner = openat(directory, name, DIRECTORY_ONLY);
    int error;

    if (inner < 0) {
        if (errno != ENOTDIR && errno != ELOOP)
            return errno;
        return unlinkat(directory, name, 0) < 0 ? errno : 0;
    }
    error = empty_directory(inner);
    close(inner);
    if (error != 0)
        return error;
    return unlinkat(directory, name, AT_REMOVEDIR) < 0 ? errno : 0;
}

/* The path removed as remove_entry removes an entry. */
static int remove_all(const char *path)
{
    int root = open(path, DIRECTORY_ONLY);
    int error;

    if (root < 0) {
        if (errno != ENOTDIR && errno != ELOOP)
            return errno;
        return unlink(path) < 0 ? errno : 0;
    }
    error = empty_directory(root);
    close(root);
    if (error != 0)
        return error;
    return rmdir(path) < 0 ? errno : 0;
}

/* The job `remove`: the path the first frame names, 'p' and its bytes,
   removed, and 'd' or 'f' and the error's name written back. */
static int remove_job(void)
{
    unsigned char head[4];
    size_t length;
    char *frame_text;
    int error;

    if (!read_all(head, sizeof head))
        return 1;
    length = (size_t)head[0] << 24 | (size_t)head[1] << 16 | (size_t)head[2] << 8 | head[3];
    if (length < 2)
        return 1;
    frame_text = malloc(length + 1);
    if (frame_text == NULL || !read_all((unsigned char *)frame_text, length)
        || frame_text[0] != 'p' || memchr(frame_text, '\0', length) != NULL) {
        free(frame_text);
        return 1;
    }
    frame_text[length] = '\0';
    error = remove_all(frame_text + 1);
    free(frame_text);
    if (error == 0) {
        frame('d', (const unsigned char *)"", 0);
    } else {
        const char *name = posix_name(error);
        frame('f', (const unsigned char *)name, strlen(name));
    }
    return 0;
}

int main(int argc, char **argv)
{
    int in[2], out[2], err[2], failed[2];
    char **program_command;

    signal(SIGPIPE, SIG_IGN);
    if (argc < 2) {
        char **variable;
        for (variable = environ; *variable != NULL; variable++)
            frame('v', (const unsigned char *)*variable, strlen(*variable));
        frame('x', (const unsigned char *)"\0\0\0\0", 4);
        return 0;
    }
    if (strcmp(argv[1], "remove") == 0)
        return remove_job();
    program_command = read_command();
    if (program_command == NULL || program_command[0] == NULL)
        return 1;
    if (pipe(in) < 0 || pipe(out) < 0 || pipe(err) < 0 || pipe(failed) < 0)
        return not_started(errno);
    fcntl(failed[1], F_SETFD, FD_CLOEXEC);

    program = fork();
    if (program < 0)
        return not_started(errno);
    if (program == 0) {
        /* the program starts with the signals as a shell would give them:
           an ignored SIGPIPE and a blocked signal would survive the exec */
        sigset_t none;
        sigemptyset(&none);
        sigprocmask(SIG_SETMASK, &none, NULL);
        signal(SIGPIPE, SIG_DFL);
        setpgid(0, 0);
        dup2(in[0], 0);
        dup2(out[1], 1);
        dup2(err[1], 2);
        close(in[0]); close(in[1]);
        close(out[0]); close(out[1]);
        close(err[0]); close(err[1]);
        close(failed[0]);
        execvp(program_command[0], program_command);
        {
            int error = errno;
            ssize_t ignored = write(failed[1], &error, sizeof error);
            (void)ignored;
        }
        _exit(127);
    }
    setpgid(program, program);
    close(in[0]); close(out[1]); close(err[1]); close(failed[1]);

    {
        int error;
        ssize_t received;
        do
            received = read(failed[0], &error, sizeof error);
        while (received < 0 && errno == EINTR);
        close(failed[0]);
        if (received == (ssize_t)sizeof error) {
            while (waitpid(program, NULL, 0) < 0 && errno == EINTR)
                ;
            program = -1;
            return not_started(error);
        }
    }
    frame('s', NULL, 0);
    fcntl(in[1], F_SETFL, fcntl(in[1], F_GETFL) | O_NONBLOCK);

    {
        /* The frame being read from the runtime: its 4-byte length, then
           its body. */
        unsigned char head[4];
        size_t head_got = 0;
        unsigned char *body = NULL;
        size_t body_size = 0, body_got = 0;
        int input_ended = 0;
        size_t wanted = 0;
        int program_in = in[1], program_out = out[0], program_err = err[0];
        unsigned char buffer[CHUNK];

        while (program_out >= 0 || program_err >= 0) {
            struct pollfd fds[4];
            int polled = 0, runtime_slot = -1, out_slot = -1, err_slot = -1, in_slot = -1;

            fds[polled].fd = 0; fds[polled].events = POLLIN; runtime_slot = polled++;
            /* the program's output is taken only while the runtime asks */
            if (program_out >= 0 && wanted > 0) {
                fds[polled].fd = program_out; fds[polled].events = POLLIN; out_slot = polled++;
            }
            if (program_err >= 0 && wanted > 0) {
                fds[polled].fd = program_err; fds[polled].events = POLLIN; err_slot = polled++;
            }
            if (program_in >= 0 && pending_size > 0) {
                fds[polled].fd = program_in; fds[polled].events = POLLOUT; in_slot = polled++;
            }
            if (poll(fds, (nfds_t)polled, -1) < 0) {
                if (errno == EINTR)
                    continue;
                free(body);
                kill_program();
                return 1;
            }

            if (runtime_slot >= 0 && fds[runtime_slot].revents) {
                ssize_t got;
                if (head_got < sizeof head)
                    got = read(0, head + head_got, sizeof head - head_got);
                else
                    got = read(0, body + body_got, body_size - body_got);
                if (got < 0 && errno == EINTR)
                    continue;
                if (got <= 0) {
                    /* the runtime has let go of the run */
                    free(body);
                    kill_program();
                    return 0;
                }
                if (head_got < sizeof head) {
                    head_got += (size_t)got;
                    if (head_got == sizeof head) {
                        body_size = ((size_t)head[0] << 24) | ((size_t)head[1] << 16)
                            | ((size_t)head[2] << 8) | (size_t)head[3];
                        body = malloc(body_size ? body_size : 1);
                        body_got = 0;
                        if (body == NULL) {
                            kill_program();
                            return 1;
                        }
                    }
                } else {
                    body_got += (size_t)got;
                }
                if (head_got == sizeof head && body_got == body_size) {
                    /* input after its end, or after the program closed
                       it, is dropped; while the input before it still
                       drains, its 'a' waits behind theirs, so that every
                       'i' is answered in order */
                    if (body_size > 0 && body[0] == 'i') {
                        if (program_in >= 0 && !input_ended) {
                            add_pending(body + 1, body_size - 1);
                            accepted += body_size - 1;
                            push_end(accepted, 0);
                        } else if (program_in >= 0) {
                            push_end(accepted, 1);
                        } else {
                            frame('d', NULL, 0);
                        }
                    }
                    else if (body_size > 0 && body[0] == 'e')
                        input_ended = 1;
                    else if (body_size > 0 && body[0] == 'n')
                        wanted++;
                    free(body);
                    body = NULL;
                    head_got = 0;
                }
            }

            if (in_slot >= 0 && fds[in_slot].revents) {
                ssize_t wrote = write(program_in, pending + pending_start, pending_size);
                if (wrote > 0) {
                    pending_start += (size_t)wrote;
                    pending_size -= (size_t)wrote;
                    if (pending_size == 0)
                        pending_start = 0;
                    taken += (uint64_t)wrote;
                } else if (wrote < 0 && errno != EAGAIN && errno != EINTR) {
                    /* the program closed its input: what it did not take is dropped */
                    pending_start = 0;
                    pending_size = 0;
                    close(program_in);
                    program_in = -1;
                    acknowledge(1);
                }
            }
            acknowledge(0);
            if (program_in >= 0 && input_ended && pending_size == 0) {
                close(program_in);
                program_in = -1;
            }

            if (out_slot >= 0 && fds[out_slot].revents) {
                ssize_t got = read(program_out, buffer, sizeof buffer);
                if (got > 0) {
                    frame('o', buffer, (size_t)got);
                    wanted--;
                }
                else if (got == 0 || errno != EINTR) {
                    close(program_out);
                    program_out = -1;
                }
            }
            if (err_slot >= 0 && fds[err_slot].revents && wanted > 0) {
                ssize_t got = read(program_err, buffer, sizeof buffer);
                if (got > 0) {
                    frame('r', buffer, (size_t)got);
                    wanted--;
                }
                else if (got == 0 || errno != EINTR) {
                    close(program_err);
                    program_err = -1;
                }
            }
        }

        /* Both outputs have ended; the run ends when the program exits,
           unless the runtime lets go of it first. Input it did not take is
           dropped, and so is a frame of the runtime's not read whole. */
        free(body);
        if (program_in >= 0)
            close(program_in);
        acknowledge(1);
        for (;;) {
            int status;
            pid_t done = waitpid(program, &status, WNOHANG);
            if (done == program) {
                unsigned char code[4];
                uint32_t value = WIFSIGNALED(status) ? 128u + (uint32_t)WTERMSIG(status)
                                                     : (uint32_t)WEXITSTATUS(status);
                code[0] = (unsigned char)(value >> 24);
                code[1] = (unsigned char)(value >> 16);
                code[2] = (unsigned char)(value >> 8);
                code[3] = (unsigned char)value;
                program = -1;
                frame('x', code, sizeof code);
                return 0;
            }
            {
                struct pollfd runtime = { 0, POLLIN, 0 };
                if (poll(&runtime, 1, 50) > 0) {
                    ssize_t got = read(0, buffer, sizeof buffer);
                    if (got == 0 || (got < 0 && errno != EINTR)) {
                        kill_program();
                        return 0;
                    }
                }
            }
        }
    }
}
