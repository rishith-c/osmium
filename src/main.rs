#![no_std]
#![no_main]

mod console;
mod fs;
mod input;
mod python;
mod shell;
mod time;
mod uart;

use core::arch::{asm, global_asm};
use core::panic::PanicInfo;

global_asm!(include_str!("boot.S"));

unsafe extern "C" {
    static mut __bss_start: u64;
    static mut __bss_end: u64;
}

#[unsafe(no_mangle)]
extern "C" fn kernel_init() -> ! {
    zero_bss();
    uart::init();
    time::init();
    fs::init();

    println!();
    println!("Osmium 0.1.0 for Raspberry Pi 4");
    println!("Booted in AArch64 bare-metal mode.");
    println!("Filesystem, shell, date, weather, and python app are ready.");
    println!();

    shell::run()
}

fn zero_bss() {
    unsafe {
        let mut current = core::ptr::addr_of_mut!(__bss_start);
        let end = core::ptr::addr_of_mut!(__bss_end);
        while current < end {
            current.write_volatile(0);
            current = current.add(1);
        }
    }
}

#[panic_handler]
fn panic(info: &PanicInfo<'_>) -> ! {
    println!("panic: {}", info);
    loop {
        unsafe {
            asm!("wfe");
        }
    }
}
