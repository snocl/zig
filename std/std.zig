const SYS_write : usize = 1;
const SYS_exit : usize = 60;
const SYS_getrandom : usize = 318;

fn syscall1(number: usize, arg1: usize) -> usize {
    asm volatile ("syscall"
        : [ret] "={rax}" (-> usize)
        : [number] "{rax}" (number), [arg1] "{rdi}" (arg1)
        : "rcx", "r11")
}

fn syscall3(number: usize, arg1: usize, arg2: usize, arg3: usize) -> usize {
    asm volatile ("syscall"
        : [ret] "={rax}" (-> usize)
        : [number] "{rax}" (number), [arg1] "{rdi}" (arg1), [arg2] "{rsi}" (arg2), [arg3] "{rdx}" (arg3)
        : "rcx", "r11")
}

pub fn write(fd: isize, buf: &const u8, count: usize) -> isize {
    syscall3(SYS_write, fd as usize, buf as usize, count) as isize
}

pub fn exit(status: i32) -> unreachable {
    syscall1(SYS_exit, status as usize);
    unreachable
}

pub fn getrandom(buf: &u8, count: usize, flags: u32) -> isize {
    syscall3(SYS_getrandom, buf as usize, count, flags as usize) as isize
}

const stdout_fileno : isize = 1;
const stderr_fileno : isize = 2;

// TODO error handling
pub fn os_get_random_bytes(buf: &u8, count: usize) -> isize {
    getrandom(buf, count, 0)
}

// TODO error handling
// TODO handle buffering and flushing (mutex protected)
pub fn print_str(str: []const u8) -> isize {
    fprint_str(stdout_fileno, str)
}

// TODO error handling
// TODO handle buffering and flushing (mutex protected)
pub fn fprint_str(fd: isize, str: []const u8) -> isize {
    write(fd, str.ptr, str.len)
}

// TODO handle buffering and flushing (mutex protected)
// TODO error handling
pub fn print_u64(x: u64) -> isize {
    // TODO use max_u64_base10_digits instead of hardcoding 20
    var buf: [20]u8;
    const len = buf_print_u64(buf.ptr, x);
    return write(stdout_fileno, buf.ptr, len);
}

// TODO handle buffering and flushing (mutex protected)
// TODO error handling
pub fn print_i64(x: i64) -> isize {
    // TODO use max_u64_base10_digits instead of hardcoding 20
    var buf: [20]u8;
    const len = buf_print_i64(buf.ptr, x);
    return write(stdout_fileno, buf.ptr, len);
}

fn digit_to_char(digit: u64) -> u8 {
    '0' + (digit as u8)
}

const max_u64_base10_digits: usize = 20;

// TODO use an array for out_buf instead of pointer. this should give bounds checking in
// debug mode and length can get optimized out in release mode. requires array slicing syntax
// for the buf_print_u64 call.
fn buf_print_i64(out_buf: &u8, x: i64) -> usize {
    if (x < 0) {
        out_buf[0] = '-';
        return 1 + buf_print_u64(&out_buf[1], ((-(x + 1)) as u64) + 1);
    } else {
        return buf_print_u64(out_buf, x as u64);
    }
}

// TODO use an array for out_buf instead of pointer.
fn buf_print_u64(out_buf: &u8, x: u64) -> usize {
    var buf: [max_u64_base10_digits]u8;
    var a = x;
    var index = buf.len;

    while (true) {
        const digit = a % 10;
        index -= 1;
        buf[index] = digit_to_char(digit);
        a /= 10;
        if (a == 0)
            break;
    }

    const len = buf.len - index;

    // TODO memcpy intrinsic
    var i: usize = 0;
    while (i < len) {
        out_buf[i] = buf[index + i];
        i += 1;
    }

    return len;
}
