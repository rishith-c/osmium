use crate::{print, println, uart};

pub fn read_line<'a>(prompt: &str, buffer: &'a mut [u8]) -> &'a str {
    print!("{}", prompt);
    let mut len = 0;

    loop {
        let byte = uart::read_byte_blocking();
        match byte {
            b'\r' | b'\n' => {
                println!();
                break;
            }
            8 | 127 => {
                if len > 0 {
                    len -= 1;
                    print!("\u{8} \u{8}");
                }
            }
            0x20..=0x7e => {
                if len < buffer.len() {
                    buffer[len] = byte;
                    len += 1;
                    uart::write_byte(byte);
                }
            }
            _ => {}
        }
    }

    core::str::from_utf8(&buffer[..len]).unwrap_or("")
}
