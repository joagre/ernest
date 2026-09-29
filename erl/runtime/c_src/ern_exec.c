/*
 * ern_exec: runs one program for Os.start (report Appendix E.23), doing what
 * the host's ports cannot: the program's standard error apart from its
 * output, the end of its input while its output is still read, and a kill
 * of the program with its process group. It is C99 over POSIX.1-2008 alone,
 * so that any POSIX host builds it; Ernest runs on Linux and macOS.
 *
 * argv[1] is the program and argv[2..] its arguments, as execvp takes
 * them. The runtime and this helper talk over fd 0 and fd 1 in frames of a
 * 4-byte big-endian length followed by a tag byte and the frame's data.
 *
 *   To the program: 'i' bytes of its input, dropped after 'e' or once the
 *   program has closed its input; 'e' the end of its input; 'n' a request
 *   for the next piece of its output. The end of fd 0 means the runtime has
 *   let go of the run: the program and its process group are killed, and
 *   the helper ends.
 *
 *   From the program: 's' it started; 'f' and an error's name, it did not
 *   start; 'a' the program has taken the bytes of one 'i', or they were
 *   dropped, one for each 'i' in order, so that a writer waits while the
 *   program is behind; 'o' bytes of its output; 'r' bytes of its standard
 *   error, each answering one 'n', so that a program no one asks waits on
 *   its output;
 *   'x' and a 4-byte big-endian status, once it has exited and both its
 *   output and its standard error have ended. A status is the program's
 *   exit code, or 128 and the signal's number for a program a signal ended.
 *
 * With no program, the helper writes its environment, which it inherited
 * as exec passes it, byte for byte: a 'v' frame for each variable, NAME=VALUE,
 * and an 'x' frame. Report Appendix E.23: the runtime reads the program's
 * environment so, since the host decodes a value that is not UTF-8 without
 * a sign.
 */
#define _POSIX_C_SOURCE 200809L
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
        ssize_t n = write(fd, data, size);
        if (n < 0 && errno == EINTR)
            continue;
        if (n <= 0) {
            /* the runtime is gone: nothing is left to answer */
            kill_program();
            _exit(1);
        }
        data += n;
        size -= (size_t)n;
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

/* The input not yet written to the program, as a growing buffer. */
static unsigned char *pending = NULL;
static size_t pending_size = 0, pending_capacity = 0;

/* The end of each 'i' not yet answered by an 'a', as a count of the input's
   bytes from its start, oldest first; taken is how many the program has
   taken, accepted how many were given. */
static uint64_t *ends = NULL;
static size_t ends_count = 0, ends_capacity = 0;
static uint64_t accepted = 0, taken = 0;

static void push_end(uint64_t end)
{
    if (ends_count == ends_capacity) {
        size_t capacity = ends_capacity ? 2 * ends_capacity : 64;
        uint64_t *grown = realloc(ends, capacity * sizeof *ends);
        if (grown == NULL) {
            kill_program();
            _exit(1);
        }
        ends = grown;
        ends_capacity = capacity;
    }
    ends[ends_count++] = end;
}

/* An 'a' for every 'i' whose bytes the program has taken, or, where its
   input is gone, for every 'i' still waiting. */
static void acknowledge(int dropped)
{
    size_t n = 0;
    while (n < ends_count && (dropped || ends[n] <= taken)) {
        frame('a', NULL, 0);
        n++;
    }
    if (n > 0) {
        memmove(ends, ends + n, (ends_count - n) * sizeof *ends);
        ends_count -= n;
    }
}

static void add_pending(const unsigned char *data, size_t size)
{
    /* nothing to add, and before the first input no buffer to add it to */
    if (size == 0)
        return;
    if (pending_size + size > pending_capacity) {
        size_t capacity = pending_capacity ? pending_capacity : CHUNK;
        while (capacity < pending_size + size)
            capacity *= 2;
        unsigned char *grown = realloc(pending, capacity);
        if (grown == NULL) {
            kill_program();
            _exit(1);
        }
        pending = grown;
        pending_capacity = capacity;
    }
    memcpy(pending + pending_size, data, size);
    pending_size += size;
}

int main(int argc, char **argv)
{
    int in[2], out[2], err[2], failed[2];

    signal(SIGPIPE, SIG_IGN);
    if (argc < 2) {
        char **variable;
        for (variable = environ; *variable != NULL; variable++)
            frame('v', (const unsigned char *)*variable, strlen(*variable));
        frame('x', (const unsigned char *)"\0\0\0\0", 4);
        return 0;
    }
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
        execvp(argv[1], &argv[1]);
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
        ssize_t n;
        do
            n = read(failed[0], &error, sizeof error);
        while (n < 0 && errno == EINTR);
        close(failed[0]);
        if (n == (ssize_t)sizeof error) {
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
        int input_ended = 0, runtime_open = 1;
        size_t wanted = 0;
        int program_in = in[1], program_out = out[0], program_err = err[0];
        unsigned char buffer[CHUNK];

        while (program_out >= 0 || program_err >= 0) {
            struct pollfd fds[4];
            int n = 0, i_runtime = -1, i_out = -1, i_err = -1, i_in = -1;

            if (runtime_open) { fds[n].fd = 0; fds[n].events = POLLIN; i_runtime = n++; }
            /* the program's output is taken only while the runtime asks */
            if (program_out >= 0 && wanted > 0) {
                fds[n].fd = program_out; fds[n].events = POLLIN; i_out = n++;
            }
            if (program_err >= 0 && wanted > 0) {
                fds[n].fd = program_err; fds[n].events = POLLIN; i_err = n++;
            }
            if (program_in >= 0 && pending_size > 0) {
                fds[n].fd = program_in; fds[n].events = POLLOUT; i_in = n++;
            }
            if (poll(fds, (nfds_t)n, -1) < 0) {
                if (errno == EINTR)
                    continue;
                free(body);
                kill_program();
                return 1;
            }

            if (i_runtime >= 0 && fds[i_runtime].revents) {
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
                            push_end(accepted);
                        } else if (program_in >= 0) {
                            push_end(accepted);
                        } else {
                            frame('a', NULL, 0);
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

            if (i_in >= 0 && fds[i_in].revents) {
                ssize_t wrote = write(program_in, pending, pending_size);
                if (wrote > 0) {
                    memmove(pending, pending + wrote, pending_size - (size_t)wrote);
                    pending_size -= (size_t)wrote;
                    taken += (uint64_t)wrote;
                } else if (wrote < 0 && errno != EAGAIN && errno != EINTR) {
                    /* the program closed its input: what it did not take is dropped */
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

            if (i_out >= 0 && fds[i_out].revents) {
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
            if (i_err >= 0 && fds[i_err].revents && wanted > 0) {
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
            if (runtime_open) {
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
