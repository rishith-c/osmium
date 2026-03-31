use core::ptr::{read_volatile, write_volatile};

const MMIO_BASE: usize = 0xFE00_0000;
const GPIO_BASE: usize = MMIO_BASE + 0x20_0000;
const UART0_BASE: usize = MMIO_BASE + 0x20_1000;

const GPFSEL1: usize = GPIO_BASE + 0x04;
const GPPUPPDN0: usize = GPIO_BASE + 0xE4;

const UART0_DR: usize = UART0_BASE + 0x00;
const UART0_FR: usize = UART0_BASE + 0x18;
const UART0_IBRD: usize = UART0_BASE + 0x24;
const UART0_FBRD: usize = UART0_BASE + 0x28;
const UART0_LCRH: usize = UART0_BASE + 0x2C;
const UART0_CR: usize = UART0_BASE + 0x30;
const UART0_IMSC: usize = UART0_BASE + 0x38;
const UART0_ICR: usize = UART0_BASE + 0x44;

pub fn init() {
    mmio_write(UART0_CR, 0);

    let mut selector = mmio_read(GPFSEL1);
    selector &= !((7 << 12) | (7 << 15));
    selector |= (4 << 12) | (4 << 15);
    mmio_write(GPFSEL1, selector);

    let mut pull = mmio_read(GPPUPPDN0);
    pull &= !((3 << 28) | (3 << 30));
    mmio_write(GPPUPPDN0, pull);

    mmio_write(UART0_ICR, 0x7ff);
    mmio_write(UART0_IBRD, 26);
    mmio_write(UART0_FBRD, 3);
    mmio_write(UART0_LCRH, (1 << 4) | (1 << 5) | (1 << 6));
    mmio_write(UART0_IMSC, 0);
    mmio_write(UART0_CR, (1 << 0) | (1 << 8) | (1 << 9));
}

pub fn write_byte(byte: u8) {
    while mmio_read(UART0_FR) & (1 << 5) != 0 {}
    mmio_write(UART0_DR, byte as u32);
}

pub fn read_byte_blocking() -> u8 {
    while mmio_read(UART0_FR) & (1 << 4) != 0 {}
    mmio_read(UART0_DR) as u8
}

pub fn write_str(text: &str) {
    for byte in text.bytes() {
        if byte == b'\n' {
            write_byte(b'\r');
        }
        write_byte(byte);
    }
}

fn mmio_read(address: usize) -> u32 {
    unsafe { read_volatile(address as *const u32) }
}

fn mmio_write(address: usize, value: u32) {
    unsafe { write_volatile(address as *mut u32, value) }
}
