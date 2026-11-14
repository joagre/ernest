/*
 * ern_exec: runs one program for Os.start and Os.startTerminal (report
 * Appendix E.23), doing what the host's ports cannot: the program's
 * standard error apart from its output, the end of its input while its
 * output is still read, a kill of the program with its process group, and
 * a run under a pseudo-terminal; and a node's lock on its ernest.pid, and a
 * signal to the node that holds one (report §12.5). It is C99 over
 * POSIX.1-2008 alone, its XSI option among it for the pseudo-terminal, so
 * that any POSIX host builds it, but for two ioctls that Linux and macOS
 * both have beyond it, TIOCSCTTY and TIOCSWINSZ; Ernest runs on Linux and
 * macOS.
 *
 * Run with the argument `run`, the helper runs the program the runtime's
 * first frame names. The runtime and this helper talk over fd 0 and fd 1 in
 * frames of a 4-byte big-endian length followed by a tag byte and the
 * frame's data.
 *
 *   To the program: first a 'v' for each variable the command sets,
 *   NAME=VALUE, set over the helper's environment in their order, and 'p'
 *   the directory it runs in, which the helper enters before it finds the
 *   program, so that a relative name resolves there; without 'p' it runs
 *   where the helper does. Then 'c', the program and then each of its
 *   arguments, each ended by a NUL byte, as execvp takes them; they come
 *   here and not on the helper's own command line, so that an argument too
 *   long for the host is the program's failure to start, and not the
 *   helper's. Then 'i' bytes of its input, dropped after 'e', once the
 *   program has exited, or once no process holds its input open; 'e' the
 *   end of its input; 'n' a request for the next piece of its output; 'k'
 *   and a signal's number in one byte, the signal sent to the program
 *   alone, not its group. The end of fd 0 means the runtime has let go of
 *   the run: the program and its process group are killed, and the helper
 *   ends.
 *
 *   From the program: 's' it started; 'f' and an error's name, it did not
 *   start; 'p' and an error's name, the helper could not enter its
 *   directory; 'a' the program has taken the bytes of one 'i', or 'd' they
 *   were dropped, one of the two for each 'i' in order, so that a writer
 *   waits while the program is behind and learns whether its bytes were
 *   taken; 'g' the signal of one 'k' was sent or the size of one 'w' set,
 *   or 'z' nothing was, the program having exited or, for a 'w', its
 *   terminal hung up, one of the two for each 'k' and each 'w' in order;
 *   'o' bytes of its output; 'r' bytes of its standard error, each
 *   answering one 'n', so that a program no one asks waits on its output;
 *   'x' and a 4-byte big-endian status, once it has exited and both its
 *   output and its standard error have ended, the processes still in its
 *   process group killed as the host reports the exit, so that none holds
 *   an output open past it. A status is the program's exit code, or 128
 *   and the signal's number for a program a signal ended.
 *   After 'x', 'f', 'p' or 't', the run's last frame, the helper drops what
 *   the runtime sends until fd 0 ends, and then ends.
 *
 * Run with the arguments `terminal`, a count of rows and one of columns,
 * each from 0 to 65535, the helper runs the program so under a
 * pseudo-terminal of that size, in the mode the host gives a new one: the
 * program its session's leader, and the terminal its controlling terminal
 * and its standard input, output and error. 't' and an error's name says
 * the terminal could not be opened or made the program's, where 'f' would
 * say the program did not start. The program's output and its standard
 * error come merged through the terminal, as 'o' alone and never 'r'.
 *
 *   Under a terminal, 'w' and its rows and its columns, each in 2 bytes,
 *   big-endian, sets the terminal's size, which the host tells the
 *   terminal's foreground of, answered as a 'k' is. 'e' hangs the terminal
 *   up at once, its master closed: the host sends the program the hangup,
 *   the input it has not taken is dropped, no more of its output is read,
 *   and 'x' comes once it has exited. A terminal that no process holds
 *   open any longer ends its input as the hangup does, since nothing can
 *   read it.
 *
 * With no argument, the helper writes what the host says of the program as
 * it starts: a 'u' frame, the user it runs as in four bytes, big-endian,
 * which the host has no word for; an 'm' frame, its file mode creation
 * mask in four bytes, big-endian, which the host has no word for either
 * and which Fs.copy takes from a new file's mode (Appendix E.17); then its
 * environment, which it inherited as exec passes it, byte for byte, a 'v'
 * frame for each variable, NAME=VALUE; and an 'x' frame. Report Appendix
 * E.23: the runtime reads the program's environment so, since the host
 * decodes a value that is not UTF-8 without a sign, and its user and its
 * mask in the same run, so that no program starts the helper twice for
 * them.
 *
 * With the argument `user`, the helper writes the 'u' frame alone, which a
 * node's check of its directory reads, as it starts and at each reload
 * (report §12.5).
 *
 * With the arguments `signal`, a signal's number and a process number, the
 * helper sends that process the signal and exits 0 where it was sent, 1
 * where no such process lives, and 2 where the process lives and is not
 * this user's to signal; the signal 0 sends nothing, and so asks whether
 * the process lives. `ern` ends so by the signal that ended a running
 * program (report §11.2), which the host has no word for.
 *
 * With the arguments `lock`, a path and a process number, the helper is a
 * node's hold on its ernest.pid (report §12.5), which the host has no word
 * for: it opens the file, made where it is not there, writable by its
 * owner alone, and never through a link, and takes the node's lock on it
 * without waiting. Where another holds that lock, it writes an 'h' frame,
 * the number the file holds, and exits. Where it took the lock, it takes
 * the write bits of the file's group and of others off a file it found
 * there, so that the file is its owner's alone to write as one it makes
 * is, writes the number and a line feed as the file's whole content, then
 * an 'l' frame, and holds the lock until fd 0 ends, which the host ends
 * with the node however the node ends; it ignores the signals a terminal
 * or a service manager sends the node's process group, so that the lock
 * goes with the node and not before it. An error is an 'f' frame and its
 * name.
 *
 * With the arguments `node`, a path and a signal's number, the helper
 * sends the signal to the node that holds the node's lock on the file at
 * the path, the process the file names, and exits 0; given `wait` after
 * them, it exits 0 once the lock has gone with the node, so that `ern
 * stop` returns once the node has ended (report §11.2). It exits 1 where
 * there is no such file, 2 where no node holds it, 8 where the file is
 * another user's and 9 where every user may write it, 3 where it names no
 * process, 4 where the process it names has ended, and 5 where that
 * process is not this user's to signal; an error is an 'f' frame and its
 * name, and 6. A signal reaches only a node so, never a process whose
 * number a file no node holds names by chance, and never one whose number
 * a user neither its owner nor of its group could have written (report
 * §11.2, §12.5). The file is opened through no link.
 *
 * The locks are POSIX's record locks, which a process holds until it
 * closes the file or ends, and which another can ask after without taking
 * them. Two bytes of the file are locked apart, whatever it holds: the
 * node's lock is the second, held for writing by the node; the first is
 * held for writing while a node takes its lock and writes its number, and
 * for reading while the number is read, so that a number read beside a
 * node's lock is that node's, whole.
 *
 * In every mode the helper first makes its environment the one `ern` was
 * started in (report Appendix E.23, §11): the launcher clears the host's
 * flags and tells the host to write no crash dump (report §10), the host's
 * own launcher sets four variables and the head of PATH, and bin/ern keeps
 * each as it was given under ERN_GIVEN_ and its
 * name, saying so with ERN_GIVEN. A program the helper runs, and the
 * environment it writes, are then the user's and not the host's.
 */
/* POSIX.1-2008 with its XSI option, which holds posix_openpt and the
   functions that ready its terminal */
#define _XOPEN_SOURCE 700
#include <errno.h>
#include <fcntl.h>
#include <signal.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/ioctl.h>
#include <sys/select.h>
#include <sys/stat.h>
#include <sys/types.h>
#include <sys/wait.h>
#include <unistd.h>

#define CHUNK 65536

extern char **environ;

static pid_t program = -1;

/* Report Appendix E.23: the program's exit wakes the helper as it happens.
   SIGCHLD writes a byte to this pipe, which the helper waits on beside the
   runtime's frames, so that it drops the program's input and kills its
   process group when the host reports the exit, whatever its outputs, and
   reports the exit once they have ended, with no timer between; an exit
   that comes between the helper's asking and its wait leaves its byte to
   be read. */
static int exited[2] = {-1, -1};

static void program_exited(int signal_number)
{
    int saved = errno;
    ssize_t ignored = write(exited[1], "x", 1);
    (void)signal_number;
    (void)ignored;
    errno = saved;
}

/* The pipe and the handler, before the program is started; each end of the
   pipe is closed in the program by its exec, and neither end ever blocks. */
static int watch_exit(void)
{
    struct sigaction action;
    int end;
    if (pipe(exited) < 0)
        return -1;
    for (end = 0; end < 2; end++) {
        fcntl(exited[end], F_SETFD, FD_CLOEXEC);
        fcntl(exited[end], F_SETFL, fcntl(exited[end], F_GETFL) | O_NONBLOCK);
    }
    memset(&action, 0, sizeof action);
    action.sa_handler = program_exited;
    sigemptyset(&action.sa_mask);
    action.sa_flags = SA_RESTART | SA_NOCLDSTOP;
    return sigaction(SIGCHLD, &action, NULL);
}

/* The command the runtime's first frames name: the 'c' frame's text, and
   the program and its arguments pointing into it, as execvp takes them,
   and the 'p' frame's text, its tag and the directory, held here so that
   they stay reachable until the helper ends. */
static char *command_text = NULL;
static char **command = NULL;
static char *directory_text = NULL;

/* The highest signal number of a host Ernest runs on; a number that names
   no signal is refused by the host, which is all that happens. */
#define SIGNALS 64

/* Report Appendix E.23, §11: the environment as `ern` was given it. Each
   variable the launcher kept goes back, one it found unset goes, and the
   launcher's own names go too, so that an `ern` this program starts
   begins as any does. Without the launcher's word, as under a test that
   runs the helper by itself, the environment stays as it is. */
static void given_environment(void)
{
    static const char *const names[] = {"PATH", "BINDIR", "EMU", "PROGNAME", "ROOTDIR",
                                        "ERL_AFLAGS", "ERL_FLAGS", "ERL_ZFLAGS", "ERL_LIBS",
                                        "ERL_CRASH_DUMP_SECONDS"};
    size_t index;

    if (getenv("ERN_GIVEN") == NULL)
        return;
    for (index = 0; index < sizeof names / sizeof names[0]; index++) {
        char kept[48];
        const char *value;
        snprintf(kept, sizeof kept, "ERN_GIVEN_%s", names[index]);
        value = getenv(kept);
        if (value != NULL)
            setenv(names[index], value, 1);
        else
            unsetenv(names[index]);
        unsetenv(kept);
    }
    unsetenv("ERN_GIVEN");
}

/* A descriptor the helper waits on, added to the set, and the highest
   such descriptor kept for select(2), which is POSIX.1-2008. The helper
   holds a handful of descriptors, each far below FD_SETSIZE, which the
   sets hold. */
static void watch(int fd, fd_set *set, int *highest)
{
    FD_SET(fd, set);
    if (fd > *highest)
        *highest = fd;
}

/* The program and every process of its group, killed and reaped. The
   program is killed by its own number too: under pipes it can leave its
   group for another of its session's, its parent's among them, which the
   group's kill then misses, and the wait would last until it ended by
   itself (report Appendix E.23: kill stops it). */
static void kill_program(void)
{
    if (program > 0) {
        kill(-program, SIGKILL);
        kill(program, SIGKILL);
        while (waitpid(program, NULL, 0) < 0 && errno == EINTR)
            ;
    }
}

/* Whether the program has exited, seen and not yet reaped, so that its
   number still names it and its process group. */
static int has_exited(void)
{
    siginfo_t ended;
    memset(&ended, 0, sizeof ended);
    return waitid(P_PID, (id_t)program, &ended, WEXITED | WNOHANG | WNOWAIT) == 0
        && ended.si_pid == program;
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

/* The name Erlang gives an error, which the runtime describes as it does
   the file system's other errors; the host's own words where Erlang has no
   name for it. Every job sends it, so that one error has one text. */
static const char *posix_name(int error)
{
    switch (error) {
    case ENOENT: return "enoent";
    case ENOTDIR: return "enotdir";
    case EACCES: return "eacces";
    case EPERM: return "eperm";
    case EISDIR: return "eisdir";
    case EROFS: return "erofs";
    case ELOOP: return "eloop";
    case EIO: return "eio";
    case ENAMETOOLONG: return "enametoolong";
    case EMFILE: return "emfile";
    case ENFILE: return "enfile";
    case ENOMEM: return "enomem";
    case ENOEXEC: return "enoexec";
    case E2BIG: return "e2big";
    case ETXTBSY: return "etxtbsy";
    default: return strerror(error);
    }
}

/* A job that failed: the frame Tag names and the host's reason, which ends
   the job's work, and the status it exits with. Report Appendix E.23: 'f'
   says the program did not start, which start answers with the host's
   reason, and 't' that its terminal could not be opened or made the
   program's, which start answers as a reason of the host's, the program
   neither missing nor denied; a job of a node's file says 'f' of its
   error (report §12.5). */
static int fail(unsigned char tag, int error, int status)
{
    const char *name = posix_name(error);
    frame(tag, (const unsigned char *)name, strlen(name));
    return status;
}

/* A run's last frame sent, 'x', 'f', 'p' or 't': what the runtime sends after
   it is read and dropped until the runtime lets go of the run, the end of
   fd 0, and the helper then exits with Status. The runtime may send a frame
   before it has read the last, a request for output or the hangup among
   them, and a frame written to a pipe whose reader has gone fails, which
   the host takes for the port's failure. */
static int wait_for_let_go(int status)
{
    unsigned char buffer[CHUNK];
    for (;;) {
        ssize_t got = read(0, buffer, sizeof buffer);
        if (got == 0 || (got < 0 && errno != EINTR))
            return status;
    }
}

/* The program's child could not become the program: the tag of the frame
   that says so, 't' where its terminal could not be made its own and 'f'
   where it did not start, and the host's reason, through the pipe the
   exec would have closed, which the helper then sends (fail). */
static void child_failed(int fd, unsigned char tag)
{
    int failure[2];
    ssize_t ignored;
    failure[0] = tag;
    failure[1] = errno;
    ignored = write(fd, failure, sizeof failure);
    (void)ignored;
    _exit(127);
}

/* Report Appendix E.23: the terminal's size, set on its master, which
   the host tells the terminal's foreground of where it changes. */
static int set_size(int master, unsigned rows, unsigned columns)
{
    struct winsize size;
    memset(&size, 0, sizeof size);
    size.ws_row = (unsigned short)rows;
    size.ws_col = (unsigned short)columns;
    return ioctl(master, TIOCSWINSZ, &size);
}

/* Report Appendix E.23: the pseudo-terminal of a run under one, of the
   size given, in the mode the host gives a new one. Its master is where
   the program's output is read and the size set, and its input a second
   descriptor of the master, which the program's input is written to and
   which closes apart, as a pipe's end would. Its terminal is opened here,
   before any process takes it as its controlling terminal, so that every
   failure is the helper's to say; -1 where the host refuses one, errno
   saying why. */
static int open_terminal(unsigned rows, unsigned columns, int *master, int *input, int *slave)
{
    const char *name = NULL;
    int error;

    *input = *slave = -1;
    *master = posix_openpt(O_RDWR | O_NOCTTY);
    if (*master < 0)
        return -1;
    if (grantpt(*master) == 0 && unlockpt(*master) == 0 && (name = ptsname(*master)) != NULL
        && set_size(*master, rows, columns) == 0 && (*input = dup(*master)) >= 0
        && (*slave = open(name, O_RDWR | O_NOCTTY)) >= 0)
        return 0;
    error = errno;
    close(*master);
    if (*input >= 0)
        close(*input);
    errno = error;
    return -1;
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

/* The program's input ended by the helper, its descriptor closed where it
   is open: what the program did not take is dropped, and every 'i' still
   waiting is answered. */
static void drop_input(int *input)
{
    if (*input >= 0)
        close(*input);
    *input = -1;
    pending_start = 0;
    pending_size = 0;
    acknowledge(1);
}

/* Report Appendix E.23: whether the program has exited, as the host
   reports it, whatever its outputs. Where it has, the processes still in
   its process group are killed with it, so that none holds an output open
   past the exit, and its input is dropped, so that a write after the exit
   is answered as one after its input's end. The program is reaped only as
   its exit is reported, so its number names its group at each call, and a
   kill after the first finds none of the group living. */
static int exit_seen(int *input)
{
    if (!has_exited())
        return 0;
    kill(-program, SIGKILL);
    drop_input(input);
    return 1;
}

/* Report Appendix E.23: a 'k' frame's signal sent to the program alone,
   not its group, 'g', or 'z' where the program has exited, which nothing
   reaches. The host refuses none of the runtime's three signals to a child
   the helper has not reaped. */
static void signal_program(int number, int *input)
{
    if (exit_seen(input)) {
        frame('z', NULL, 0);
    } else {
        kill(program, number);
        frame('g', NULL, 0);
    }
}

/* Report Appendix E.23: a 'w' frame's size set on the terminal's master,
   'g', or 'z' where the terminal is hung up, its master closed, or the
   program has exited, which nothing is told. The host refuses no size of 0
   to 65535 on a master the helper holds. */
static void resize_terminal(int master, unsigned rows, unsigned columns, int *input)
{
    if (master < 0 || exit_seen(input)) {
        frame('z', NULL, 0);
    } else {
        set_size(master, rows, columns);
        frame('g', NULL, 0);
    }
}

/* Report Appendix E.23: the program's exit, seen and its process group
   killed (exit_seen), the program reaped and its status sent. */
static void report_exit(void)
{
    int status;
    uint32_t value;
    unsigned char code[4];

    while (waitpid(program, &status, 0) < 0 && errno == EINTR)
        ;
    value = WIFSIGNALED(status) ? 128u + (uint32_t)WTERMSIG(status)
                                : (uint32_t)WEXITSTATUS(status);
    code[0] = (unsigned char)(value >> 24);
    code[1] = (unsigned char)(value >> 16);
    code[2] = (unsigned char)(value >> 8);
    code[3] = (unsigned char)value;
    program = -1;
    frame('x', code, sizeof code);
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

/* A frame of the runtime's, read whole, its body ended by a NUL byte past
   its size, so that a frame of text is a string; NULL where the runtime let
   go first, the frame is empty, or the host has no room for it. */
static char *read_frame(size_t *size)
{
    unsigned char head[4];
    char *body;

    if (!read_all(head, sizeof head))
        return NULL;
    *size = (size_t)head[0] << 24 | (size_t)head[1] << 16 | (size_t)head[2] << 8 | head[3];
    if (*size == 0 || (body = malloc(*size + 1)) == NULL)
        return NULL;
    if (!read_all((unsigned char *)body, *size)) {
        free(body);
        return NULL;
    }
    body[*size] = '\0';
    return body;
}

/* Report Appendix E.23: a 'v' frame's variable, NAME=VALUE, set over the
   helper's environment, so that the last of two with one name stands; 0
   where it is not one, its name empty or the frame holding a NUL byte. */
static int set_variable(char *variable, size_t size)
{
    char *equals = strchr(variable, '=');
    if (strlen(variable) != size || equals == NULL || equals == variable)
        return 0;
    *equals = '\0';
    return setenv(variable, equals + 1, 1) == 0;
}

/* The runtime's first frames (above): each 'v' set over the helper's
   environment, the directory 'p' names kept, and last the command, 'c' and
   at least the program, each part ended by a NUL byte, as execvp takes
   it; NULL where they are not that. An empty program is one, which execvp
   finds nowhere (report Appendix E.23: NotFound). */
static char **read_command(void)
{
    size_t length, at, parts = 0, part;

    for (;;) {
        char *body = read_frame(&length);
        if (body == NULL)
            return NULL;
        if (body[0] == 'c') {
            command_text = body;
            break;
        }
        if (body[0] == 'v' && set_variable(body + 1, length - 1)) {
            free(body);
        } else if (body[0] == 'p' && directory_text == NULL && strlen(body + 1) == length - 1) {
            directory_text = body;
        } else {
            free(body);
            return NULL;
        }
    }
    if (length < 2 || command_text[length - 1] != '\0')
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

/* The number a decimal argument writes, or -1 for one that writes none:
   digits alone, as many as a process number takes. */
static long number_of(const char *text)
{
    long value = 0;
    const char *digit;
    if (*text == '\0' || strlen(text) > 9)
        return -1;
    for (digit = text; *digit != '\0'; digit++) {
        if (*digit < '0' || *digit > '9')
            return -1;
        value = value * 10 + (*digit - '0');
    }
    return value;
}

/* `terminal ROWS COLUMNS`: the size a run under a terminal begins with,
   each count from 0 to 65535, which the host's size holds; 0 where the
   arguments are not that. */
static int terminal_size(int argc, char **argv, unsigned *rows, unsigned *columns)
{
    long given_rows, given_columns;
    if (argc != 4)
        return 0;
    given_rows = number_of(argv[2]);
    given_columns = number_of(argv[3]);
    if (given_rows < 0 || given_rows > 65535 || given_columns < 0 || given_columns > 65535)
        return 0;
    *rows = (unsigned)given_rows;
    *columns = (unsigned)given_columns;
    return 1;
}

/* `signal NUMBER PROCESS`: the signal sent, and how it went (above). A
   process number below 1 would name a process group or every process, and
   is refused. */
static int send_signal(int argc, char **argv)
{
    long number, process;
    if (argc != 4)
        return 3;
    number = number_of(argv[2]);
    process = number_of(argv[3]);
    if (number < 0 || number > SIGNALS || process < 1)
        return 3;
    if (kill((pid_t)process, (int)number) == 0)
        return 0;
    return errno == EPERM ? 2 : 1;
}

/* The 'u' frame: the user the helper runs as, in four bytes, big-endian. */
static void user_frame(void)
{
    uint32_t user = (uint32_t)geteuid();
    unsigned char bytes[4] = {
        (unsigned char)(user >> 24), (unsigned char)(user >> 16),
        (unsigned char)(user >> 8), (unsigned char)user
    };
    frame('u', bytes, sizeof bytes);
}

/* The bytes of a node's file that are locked (above): the number's, and
   the node's. */
#define NUMBER_BYTE 0
#define NODE_BYTE 1

/* A lock of the given type over one byte of a node's file, taken, let go
   or asked after as Command says, waited for where it is F_SETLKW. */
static int byte_lock(int fd, int command, short type, off_t byte, struct flock *lock)
{
    memset(lock, 0, sizeof *lock);
    lock->l_type = type;
    lock->l_whence = SEEK_SET;
    lock->l_start = byte;
    lock->l_len = 1;
    for (;;) {
        if (fcntl(fd, command, lock) == 0)
            return 0;
        if (errno != EINTR)
            return -1;
    }
}

/* The number a node's file holds, read whole while the number's byte is
   held: -1 where it holds none, and -2 where it cannot be read. */
static long number_held(int fd)
{
    char text[16];
    ssize_t got = pread(fd, text, sizeof text - 1, 0);
    if (got < 0)
        return -2;
    text[got] = '\0';
    if (got > 0 && text[got - 1] == '\n')
        text[got - 1] = '\0';
    return number_of(text);
}

/* `lock PATH NUMBER`: the node's hold on its ernest.pid (above). The
   signals are ignored before the lock is taken, so that none ends the hold
   while the node lives. Report §12.5: a file it makes is writable by its
   owner alone, whatever the mask, which takes bits away and adds none; a
   file it finds, an earlier node's that others may write among them, is
   made so once the lock is held, its other bits as they were; and one at
   the path that is a link is refused, not followed. */
static int hold_lock(int argc, char **argv)
{
    static const int ignored[] = {SIGHUP, SIGINT, SIGQUIT, SIGTERM};
    struct flock lock;
    struct stat status;
    unsigned char buffer[64];
    char text[16];
    long number;
    size_t index;
    int fd, length;

    if (argc != 4 || (number = number_of(argv[3])) < 1)
        return 7;
    for (index = 0; index < sizeof ignored / sizeof ignored[0]; index++)
        signal(ignored[index], SIG_IGN);
    fd = open(argv[2], O_RDWR | O_CREAT | O_CLOEXEC | O_NOFOLLOW, 0644);
    if (fd < 0 || byte_lock(fd, F_SETLKW, F_WRLCK, NUMBER_BYTE, &lock) < 0)
        return fail('f', errno, 1);
    if (byte_lock(fd, F_SETLK, F_WRLCK, NODE_BYTE, &lock) < 0) {
        long held;
        if ((errno != EACCES && errno != EAGAIN)
            || byte_lock(fd, F_GETLK, F_WRLCK, NODE_BYTE, &lock) < 0)
            return fail('f', errno, 1);
        if (lock.l_type == F_WRLCK) {
            held = number_held(fd);
            length = held < 0 ? 0 : snprintf(text, sizeof text, "%ld", held);
            frame('h', (const unsigned char *)text, (size_t)length);
            return 0;
        }
        /* held for reading alone, by an `ern stop` whose node has ended,
           which lets it go at once; no node can take it meanwhile, since
           this one holds the number's byte */
        if (byte_lock(fd, F_SETLKW, F_WRLCK, NODE_BYTE, &lock) < 0)
            return fail('f', errno, 1);
    }
    if (fstat(fd, &status) < 0
        || ((status.st_mode & (S_IWGRP | S_IWOTH))
            && fchmod(fd, status.st_mode & 07777 & ~(mode_t)(S_IWGRP | S_IWOTH)) < 0))
        return fail('f', errno, 1);
    length = snprintf(text, sizeof text, "%ld\n", number);
    if (ftruncate(fd, 0) < 0 || pwrite(fd, text, (size_t)length, 0) != length
        || byte_lock(fd, F_SETLK, F_UNLCK, NUMBER_BYTE, &lock) < 0)
        return fail('f', errno, 1);
    frame('l', NULL, 0);
    for (;;) {
        ssize_t got = read(0, buffer, sizeof buffer);
        if (got == 0 || (got < 0 && errno != EINTR))
            return 0;
    }
}

/* Report §11.2, §12.5: whether the file at fd names a process this user
   may signal as its node, the file alone tested, since it was opened
   through no link: 8 where it is neither this user's own nor the
   superuser's, 9 where every user may write it, the bits for its group
   not read, 0 where neither holds, and 6 where the host cannot say, its
   error in an 'f' frame. */
static int own_file(int fd)
{
    struct stat status;
    if (fstat(fd, &status) < 0)
        return fail('f', errno, 6);
    if (status.st_uid != geteuid() && status.st_uid != 0)
        return 8;
    if (status.st_mode & S_IWOTH)
        return 9;
    return 0;
}

/* `node PATH SIGNAL [wait]`: the signal sent to the node that holds the
   node's lock on the file (above). A node holds it for writing; held for
   reading, it is another `ern stop`'s, waiting, and no node's. The number
   is read while its byte is held, from a file none but this user may have
   written, and the lock waited for once it is let go. */
static int signal_node(int argc, char **argv)
{
    struct flock lock;
    long number, process;
    int fd, owned;

    if (argc < 4 || argc > 5 || (argc == 5 && strcmp(argv[4], "wait") != 0))
        return 7;
    number = number_of(argv[3]);
    if (number < 0 || number > SIGNALS)
        return 7;
    fd = open(argv[2], O_RDONLY | O_CLOEXEC | O_NOFOLLOW);
    if (fd < 0)
        return errno == ENOENT ? 1 : fail('f', errno, 6);
    if (byte_lock(fd, F_SETLKW, F_RDLCK, NUMBER_BYTE, &lock) < 0)
        return fail('f', errno, 6);
    if (byte_lock(fd, F_GETLK, F_WRLCK, NODE_BYTE, &lock) < 0)
        return fail('f', errno, 6);
    if (lock.l_type != F_WRLCK)
        return 2;
    if ((owned = own_file(fd)) != 0)
        return owned;
    process = number_held(fd);
    if (process == -2)
        return fail('f', errno, 6);
    if (process < 1)
        return 3;
    if (byte_lock(fd, F_SETLK, F_UNLCK, NUMBER_BYTE, &lock) < 0)
        return fail('f', errno, 6);
    if (kill((pid_t)process, (int)number) < 0)
        return errno == EPERM ? 5 : 4;
    if (argc == 5 && byte_lock(fd, F_SETLKW, F_RDLCK, NODE_BYTE, &lock) < 0)
        return fail('f', errno, 6);
    return 0;
}

int main(int argc, char **argv)
{
    int in[2], out[2], err[2], start_failure[2];
    int terminal = 0, master = -1, input = -1, slave = -1;
    int program_in, program_out, program_err;
    unsigned rows = 0, columns = 0;
    char **program_command;

    given_environment();
    signal(SIGPIPE, SIG_IGN);
    if (argc < 2) {
        char **variable;
        mode_t mask = umask(0);
        uint32_t mask_bits = (uint32_t)mask;
        unsigned char mask_bytes[4] = {
            (unsigned char)(mask_bits >> 24), (unsigned char)(mask_bits >> 16),
            (unsigned char)(mask_bits >> 8), (unsigned char)mask_bits
        };
        umask(mask);
        user_frame();
        frame('m', mask_bytes, sizeof mask_bytes);
        for (variable = environ; *variable != NULL; variable++)
            frame('v', (const unsigned char *)*variable, strlen(*variable));
        frame('x', (const unsigned char *)"\0\0\0\0", 4);
        return 0;
    }
    if (strcmp(argv[1], "user") == 0) {
        user_frame();
        return 0;
    }
    if (strcmp(argv[1], "signal") == 0)
        return send_signal(argc, argv);
    if (strcmp(argv[1], "lock") == 0)
        return hold_lock(argc, argv);
    if (strcmp(argv[1], "node") == 0)
        return signal_node(argc, argv);
    if (strcmp(argv[1], "terminal") == 0) {
        if (!terminal_size(argc, argv, &rows, &columns))
            return 1;
        terminal = 1;
    } else if (strcmp(argv[1], "run") != 0) {
        return 1;
    }
    program_command = read_command();
    if (program_command == NULL || program_command[0] == NULL)
        return 1;
    /* Report Appendix E.23: the directory entered before the program is
       found, the host's order, so that a relative name resolves there; one
       the helper cannot enter is its own to say, before any program runs */
    if (directory_text != NULL && chdir(directory_text + 1) < 0)
        return wait_for_let_go(fail('p', errno, 0));
    /* the terminal before the handler of SIGCHLD, with which grantpt's
       page leaves its work unspecified */
    if (terminal) {
        if (open_terminal(rows, columns, &master, &input, &slave) < 0)
            return wait_for_let_go(fail('t', errno, 0));
    } else if (pipe(in) < 0 || pipe(out) < 0 || pipe(err) < 0) {
        return wait_for_let_go(fail('f', errno, 0));
    }
    if (pipe(start_failure) < 0 || watch_exit() < 0)
        return wait_for_let_go(fail('f', errno, 0));
    fcntl(start_failure[1], F_SETFD, FD_CLOEXEC);

    program = fork();
    if (program < 0)
        return wait_for_let_go(fail('f', errno, 0));
    if (program == 0) {
        /* the program starts with the signals as a shell would give them:
           a signal the host or this helper ignores, and a blocked one,
           would survive the exec */
        sigset_t none;
        int number;
        sigemptyset(&none);
        sigprocmask(SIG_SETMASK, &none, NULL);
        for (number = 1; number <= SIGNALS; number++)
            signal(number, SIG_DFL);
        if (terminal) {
            /* Report Appendix E.23: the program its session's leader, and so
               its process group's, with the terminal as its controlling
               terminal, which TIOCSCTTY makes it where opening it did not,
               and as its standard input, output and error; a step the host
               refuses is the terminal's failure */
            if (setsid() < 0 || ioctl(slave, TIOCSCTTY, 0) < 0 || dup2(slave, 0) < 0
                || dup2(slave, 1) < 0 || dup2(slave, 2) < 0)
                child_failed(start_failure[1], 't');
            if (slave > 2)
                close(slave);
            close(master); close(input);
        } else {
            setpgid(0, 0);
            if (dup2(in[0], 0) < 0 || dup2(out[1], 1) < 0 || dup2(err[1], 2) < 0)
                child_failed(start_failure[1], 'f');
            close(in[0]); close(in[1]);
            close(out[0]); close(out[1]);
            close(err[0]); close(err[1]);
        }
        close(start_failure[0]);
        execvp(program_command[0], program_command);
        child_failed(start_failure[1], 'f');
    }
    /* a program under a terminal makes its own group as it makes its
       session, which a group made here first would refuse */
    if (terminal) {
        close(slave);
        program_in = input;
        program_out = master;
        program_err = -1;
    } else {
        setpgid(program, program);
        close(in[0]); close(out[1]); close(err[1]);
        program_in = in[1];
        program_out = out[0];
        program_err = err[0];
    }
    close(start_failure[1]);

    {
        int failure[2];
        ssize_t received;
        do
            received = read(start_failure[0], failure, sizeof failure);
        while (received < 0 && errno == EINTR);
        close(start_failure[0]);
        if (received == (ssize_t)sizeof failure) {
            while (waitpid(program, NULL, 0) < 0 && errno == EINTR)
                ;
            program = -1;
            return wait_for_let_go(fail((unsigned char)failure[0], failure[1], 0));
        }
    }
    frame('s', NULL, 0);
    fcntl(program_in, F_SETFL, fcntl(program_in, F_GETFL) | O_NONBLOCK);

    {
        /* The frame being read from the runtime: its 4-byte length, then
           its body. */
        unsigned char head[4];
        size_t head_got = 0;
        unsigned char *body = NULL;
        size_t body_size = 0, body_got = 0;
        int input_ended = 0;
        size_t wanted = 0;
        unsigned char buffer[CHUNK];

        for (;;) {
            fd_set readable, writable;
            int highest = 0, out_watched = 0, err_watched = 0, in_watched = 0;
            /* Report Appendix E.23: once both outputs have ended, a hung-up
               terminal's among them, the run ends when the program exits,
               unless the runtime lets go of it first; a frame of the
               runtime's not read whole is dropped */
            int outputs_ended = program_out < 0 && program_err < 0;

            if (outputs_ended && exit_seen(&program_in)) {
                free(body);
                report_exit();
                return wait_for_let_go(0);
            }
            FD_ZERO(&readable);
            FD_ZERO(&writable);
            watch(0, &readable, &highest);
            /* the program's output is taken only while the runtime asks */
            if (program_out >= 0 && wanted > 0) {
                watch(program_out, &readable, &highest);
                out_watched = 1;
            }
            if (program_err >= 0 && wanted > 0) {
                watch(program_err, &readable, &highest);
                err_watched = 1;
            }
            if (program_in >= 0 && pending_size > 0) {
                watch(program_in, &writable, &highest);
                in_watched = 1;
            }
            watch(exited[0], &readable, &highest);
            /* Report Appendix E.23: select(2), since poll(2) does not serve a
               device on macOS, which a pseudo-terminal's master is */
            if (select(highest + 1, &readable, &writable, NULL, NULL) < 0) {
                if (errno == EINTR)
                    continue;
                free(body);
                kill_program();
                return 1;
            }

            /* the exit kills the group, whose outputs then end, and drops
               the input before a frame sent after it is read */
            if (FD_ISSET(exited[0], &readable)) {
                while (read(exited[0], buffer, sizeof buffer) > 0)
                    ;
                exit_seen(&program_in);
            }

            if (FD_ISSET(0, &readable)) {
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
                    else if (body_size == 5 && body[0] == 'w' && terminal)
                        resize_terminal(program_out, (unsigned)body[1] << 8 | body[2],
                                        (unsigned)body[3] << 8 | body[4], &program_in);
                    else if (body_size == 2 && body[0] == 'k')
                        signal_program(body[1], &program_in);
                    free(body);
                    body = NULL;
                    head_got = 0;
                }
            }

            /* the exit may have dropped the input since it was watched */
            if (in_watched && program_in >= 0 && FD_ISSET(program_in, &writable)) {
                ssize_t wrote = write(program_in, pending + pending_start, pending_size);
                if (wrote > 0) {
                    pending_start += (size_t)wrote;
                    pending_size -= (size_t)wrote;
                    if (pending_size == 0)
                        pending_start = 0;
                    taken += (uint64_t)wrote;
                } else if (wrote < 0 && errno != EAGAIN && errno != EINTR) {
                    /* no process holds the program's input open */
                    drop_input(&program_in);
                }
            }
            acknowledge(0);
            if (program_in >= 0 && input_ended && pending_size == 0) {
                close(program_in);
                program_in = -1;
            }

            if (out_watched && FD_ISSET(program_out, &readable)) {
                ssize_t got = read(program_out, buffer, sizeof buffer);
                if (got > 0) {
                    frame('o', buffer, (size_t)got);
                    wanted--;
                }
                /* a terminal's master is its input's too, which writes
                   without waiting, so a read may find nothing yet; a
                   terminal no process holds open any longer takes no
                   input */
                else if (got == 0 || (errno != EINTR && errno != EAGAIN)) {
                    close(program_out);
                    program_out = -1;
                    if (terminal)
                        drop_input(&program_in);
                }
            }
            if (err_watched && FD_ISSET(program_err, &readable) && wanted > 0) {
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

            /* Report Appendix E.23: under a terminal the end of the input is
               its hangup, at once: its master closed, the host sends the
               program the hangup, the input it has not taken is dropped,
               and nothing more it writes is read */
            if (terminal && input_ended && program_out >= 0) {
                close(program_out);
                program_out = -1;
                drop_input(&program_in);
            }
        }
    }
}
