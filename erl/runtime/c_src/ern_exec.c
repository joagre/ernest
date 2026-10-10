/*
 * ern_exec: runs one program for Os.start (report Appendix E.23), doing what
 * the host's ports cannot: the program's standard error apart from its
 * output, the end of its input while its output is still read, and a kill
 * of the program with its process group; and a node's lock on its
 * ernest.pid, and a signal to the node that holds one (report §8.7). It is
 * C99 over POSIX.1-2008 alone, so that any POSIX host builds it; Ernest
 * runs on Linux and macOS.
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
 *   bytes of its input, dropped after 'e' or once the program has closed
 *   its input; 'e' the end of its input; 'n' a request for the next piece
 *   of its output. The end of fd 0 means the runtime has let go of the
 *   run: the program and its process group are killed, and the helper
 *   ends.
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
 * (report §8.7).
 *
 * With the arguments `signal`, a signal's number and a process number, the
 * helper sends that process the signal and exits 0 where it was sent, 1
 * where no such process lives, and 2 where the process lives and is not
 * this user's to signal; the signal 0 sends nothing, and so asks whether
 * the process lives. `ern` ends so by the signal that ended a running
 * program (report §11.2), which the host has no word for.
 *
 * With the arguments `lock`, a path and a process number, the helper is a
 * node's hold on its ernest.pid (report §8.7), which the host has no word
 * for: it opens the file, made where it is not there, and takes the node's
 * lock on it without waiting. Where another holds that lock, it writes an
 * 'h' frame, the number the file holds, and exits. Where it took the lock,
 * it writes the number and a line feed as the file's whole content, then
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
 * there is no such file, 2 where no node holds it, 3 where it names no
 * process, 4 where the process it names has ended, and 5 where that
 * process is not this user's to signal; an error is an 'f' frame and its
 * name, and 6. A signal reaches only a node so, and never a process whose
 * number a file no node holds names by chance.
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
#define _POSIX_C_SOURCE 200809L
#include <errno.h>
#include <fcntl.h>
#include <poll.h>
#include <signal.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/stat.h>
#include <sys/types.h>
#include <sys/wait.h>
#include <unistd.h>

#define CHUNK 65536

extern char **environ;

static pid_t program = -1;

/* Report Appendix E.23: the program's exit wakes the helper as it happens.
   SIGCHLD writes a byte to this pipe, which the helper polls beside the
   runtime's frames once the program's outputs have ended, so no timer
   stands between the exit and its report, and an exit that comes between
   the helper's asking and its poll leaves its byte to be read. */
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

/* The command the runtime's first frame names: the frame's text, and the
   program and its arguments pointing into it, as execvp takes them, held
   here so that they stay reachable until the helper ends. */
static char *command_text = NULL;
static char **command = NULL;

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

/* The name Erlang gives an error, which the runtime describes as it does
   the file system's other errors; the host's own words where Erlang has no
   name for it. Both jobs send it, so that one error has one text. */
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
    case ENOEXEC: return "enoexec";
    case E2BIG: return "e2big";
    case ETXTBSY: return "etxtbsy";
    default: return strerror(error);
    }
}

/* The program did not start: the host's reason, in an 'f' frame, which ends
   the helper's work (report Appendix E.23: start answers the host's
   reason). */
static int not_started(int error)
{
    const char *name = posix_name(error);
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
   one. An empty program is one, which execvp finds nowhere (report
   Appendix E.23: NotFound). */
static char **read_command(void)
{
    unsigned char head[4];
    size_t length, at, parts = 0, part;

    if (!read_all(head, sizeof head))
        return NULL;
    length = (size_t)head[0] << 24 | (size_t)head[1] << 16 | (size_t)head[2] << 8 | head[3];
    if (length < 2)
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

/* An 'f' frame and the error's name, which ends a job of a node's file. */
static int failed(int error, int status)
{
    const char *name = posix_name(error);
    frame('f', (const unsigned char *)name, strlen(name));
    return status;
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
   while the node lives. */
static int hold_lock(int argc, char **argv)
{
    static const int ignored[] = {SIGHUP, SIGINT, SIGQUIT, SIGTERM};
    struct flock lock;
    unsigned char buffer[64];
    char text[16];
    long number;
    size_t index;
    int fd, length;

    if (argc != 4 || (number = number_of(argv[3])) < 1)
        return 7;
    for (index = 0; index < sizeof ignored / sizeof ignored[0]; index++)
        signal(ignored[index], SIG_IGN);
    fd = open(argv[2], O_RDWR | O_CREAT | O_CLOEXEC, 0666);
    if (fd < 0 || byte_lock(fd, F_SETLKW, F_WRLCK, NUMBER_BYTE, &lock) < 0)
        return failed(errno, 1);
    if (byte_lock(fd, F_SETLK, F_WRLCK, NODE_BYTE, &lock) < 0) {
        long held;
        if ((errno != EACCES && errno != EAGAIN)
            || byte_lock(fd, F_GETLK, F_WRLCK, NODE_BYTE, &lock) < 0)
            return failed(errno, 1);
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
            return failed(errno, 1);
    }
    length = snprintf(text, sizeof text, "%ld\n", number);
    if (ftruncate(fd, 0) < 0 || pwrite(fd, text, (size_t)length, 0) != length
        || byte_lock(fd, F_SETLK, F_UNLCK, NUMBER_BYTE, &lock) < 0)
        return failed(errno, 1);
    frame('l', NULL, 0);
    for (;;) {
        ssize_t got = read(0, buffer, sizeof buffer);
        if (got == 0 || (got < 0 && errno != EINTR))
            return 0;
    }
}

/* `node PATH SIGNAL [wait]`: the signal sent to the node that holds the
   node's lock on the file (above). A node holds it for writing; held for
   reading, it is another `ern stop`'s, waiting, and no node's. The number
   is read while its byte is held, and the lock waited for once it is let
   go. */
static int signal_node(int argc, char **argv)
{
    struct flock lock;
    long number, process;
    int fd;

    if (argc < 4 || argc > 5 || (argc == 5 && strcmp(argv[4], "wait") != 0))
        return 7;
    number = number_of(argv[3]);
    if (number < 0 || number > SIGNALS)
        return 7;
    fd = open(argv[2], O_RDONLY | O_CLOEXEC);
    if (fd < 0)
        return errno == ENOENT ? 1 : failed(errno, 6);
    if (byte_lock(fd, F_SETLKW, F_RDLCK, NUMBER_BYTE, &lock) < 0)
        return failed(errno, 6);
    if (byte_lock(fd, F_GETLK, F_WRLCK, NODE_BYTE, &lock) < 0)
        return failed(errno, 6);
    if (lock.l_type != F_WRLCK)
        return 2;
    process = number_held(fd);
    if (process == -2)
        return failed(errno, 6);
    if (process < 1)
        return 3;
    if (byte_lock(fd, F_SETLK, F_UNLCK, NUMBER_BYTE, &lock) < 0)
        return failed(errno, 6);
    if (kill((pid_t)process, (int)number) < 0)
        return errno == EPERM ? 5 : 4;
    if (argc == 5 && byte_lock(fd, F_SETLKW, F_RDLCK, NODE_BYTE, &lock) < 0)
        return failed(errno, 6);
    return 0;
}

int main(int argc, char **argv)
{
    int in[2], out[2], err[2], failed[2];
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
    if (strcmp(argv[1], "run") != 0)
        return 1;
    program_command = read_command();
    if (program_command == NULL || program_command[0] == NULL)
        return 1;
    if (pipe(in) < 0 || pipe(out) < 0 || pipe(err) < 0 || pipe(failed) < 0
        || watch_exit() < 0)
        return not_started(errno);
    fcntl(failed[1], F_SETFD, FD_CLOEXEC);

    program = fork();
    if (program < 0)
        return not_started(errno);
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
            struct pollfd woken[2];
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
            /* the program has not ended yet: wait for its exit, or for the
               runtime to let go, with no timer */
            woken[0].fd = 0; woken[0].events = POLLIN; woken[0].revents = 0;
            woken[1].fd = exited[0]; woken[1].events = POLLIN; woken[1].revents = 0;
            if (poll(woken, 2, -1) < 0) {
                if (errno == EINTR)
                    continue;
                kill_program();
                return 1;
            }
            if (woken[1].revents) {
                while (read(exited[0], buffer, sizeof buffer) > 0)
                    ;
            }
            if (woken[0].revents) {
                ssize_t got = read(0, buffer, sizeof buffer);
                if (got == 0 || (got < 0 && errno != EINTR)) {
                    kill_program();
                    return 0;
                }
            }
        }
    }
}
