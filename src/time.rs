use core::arch::asm;
use core::sync::atomic::{AtomicBool, AtomicI64, AtomicU64, Ordering};

static COUNTER_START: AtomicU64 = AtomicU64::new(0);
static COUNTER_FREQ: AtomicU64 = AtomicU64::new(0);
static UNIX_OFFSET: AtomicI64 = AtomicI64::new(0);
static CLOCK_SYNCED: AtomicBool = AtomicBool::new(false);

pub fn init() {
    let mut start = 0u64;
    let mut freq = 0u64;
    unsafe {
        asm!("mrs {0}, cntpct_el0", out(reg) start);
        asm!("mrs {0}, cntfrq_el0", out(reg) freq);
    }
    COUNTER_START.store(start, Ordering::Relaxed);
    COUNTER_FREQ.store(freq.max(1), Ordering::Relaxed);
}

pub fn uptime_seconds() -> u64 {
    let mut now = 0u64;
    unsafe {
        asm!("mrs {0}, cntpct_el0", out(reg) now);
    }
    let elapsed_ticks = now.saturating_sub(COUNTER_START.load(Ordering::Relaxed));
    elapsed_ticks / COUNTER_FREQ.load(Ordering::Relaxed)
}

pub fn unix_seconds() -> i64 {
    UNIX_OFFSET.load(Ordering::Relaxed) + uptime_seconds() as i64
}

pub fn set_unix_seconds(seconds: i64) {
    UNIX_OFFSET.store(seconds - uptime_seconds() as i64, Ordering::Relaxed);
    CLOCK_SYNCED.store(true, Ordering::Relaxed);
}

pub fn is_synced() -> bool {
    CLOCK_SYNCED.load(Ordering::Relaxed)
}

pub fn format_now<'a>(buffer: &'a mut [u8; 32]) -> &'a str {
    format_timestamp(unix_seconds(), buffer)
}

fn format_timestamp<'a>(seconds: i64, buffer: &'a mut [u8; 32]) -> &'a str {
    let (year, month, day, hour, minute, second) = split_timestamp(seconds);
    let mut index = 0usize;
    index += write_number(&mut buffer[index..], year as i64, 4);
    buffer[index] = b'-';
    index += 1;
    index += write_number(&mut buffer[index..], month as i64, 2);
    buffer[index] = b'-';
    index += 1;
    index += write_number(&mut buffer[index..], day as i64, 2);
    buffer[index] = b'T';
    index += 1;
    index += write_number(&mut buffer[index..], hour as i64, 2);
    buffer[index] = b':';
    index += 1;
    index += write_number(&mut buffer[index..], minute as i64, 2);
    buffer[index] = b':';
    index += 1;
    index += write_number(&mut buffer[index..], second as i64, 2);
    buffer[index] = b'Z';
    index += 1;
    core::str::from_utf8(&buffer[..index]).unwrap_or("1970-01-01T00:00:00Z")
}

fn split_timestamp(seconds: i64) -> (i32, u32, u32, u32, u32, u32) {
    let days = div_floor(seconds, 86_400);
    let seconds_of_day = seconds - days * 86_400;
    let (year, month, day) = civil_from_days(days);
    let hour = (seconds_of_day / 3_600) as u32;
    let minute = ((seconds_of_day % 3_600) / 60) as u32;
    let second = (seconds_of_day % 60) as u32;
    (year, month, day, hour, minute, second)
}

fn div_floor(numerator: i64, denominator: i64) -> i64 {
    let mut quotient = numerator / denominator;
    let remainder = numerator % denominator;
    if remainder < 0 {
        quotient -= 1;
    }
    quotient
}

fn civil_from_days(days: i64) -> (i32, u32, u32) {
    let z = days + 719_468;
    let era = if z >= 0 { z } else { z - 146_096 } / 146_097;
    let doe = z - era * 146_097;
    let yoe = (doe - doe / 1_460 + doe / 36_524 - doe / 146_096) / 365;
    let mut year = (yoe + era * 400) as i32;
    let doy = doe - (365 * yoe + yoe / 4 - yoe / 100);
    let mp = (5 * doy + 2) / 153;
    let day = (doy - (153 * mp + 2) / 5 + 1) as u32;
    let month = (mp + if mp < 10 { 3 } else { -9 }) as u32;
    if month <= 2 {
        year += 1;
    }
    (year, month, day)
}

fn write_number(buffer: &mut [u8], value: i64, width: usize) -> usize {
    let mut digits = [0u8; 20];
    let mut value = value as u64;
    let mut len = 0usize;

    loop {
        digits[len] = (value % 10) as u8 + b'0';
        value /= 10;
        len += 1;
        if value == 0 {
            break;
        }
    }

    while len < width {
        digits[len] = b'0';
        len += 1;
    }

    let mut index = 0usize;
    while index < len {
        buffer[index] = digits[len - 1 - index];
        index += 1;
    }
    len
}
