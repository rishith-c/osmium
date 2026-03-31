use core::fmt::{self, Write};

struct Console;

impl Write for Console {
    fn write_str(&mut self, s: &str) -> fmt::Result {
        crate::uart::write_str(s);
        Ok(())
    }
}

pub fn _print(args: fmt::Arguments<'_>) {
    let mut console = Console;
    let _ = console.write_fmt(args);
}

#[macro_export]
macro_rules! print {
    ($($arg:tt)*) => ({
        $crate::console::_print(core::format_args!($($arg)*));
    });
}

#[macro_export]
macro_rules! println {
    () => ({
        $crate::print!("\n");
    });
    ($fmt:expr) => ({
        $crate::print!(concat!($fmt, "\n"));
    });
    ($fmt:expr, $($arg:tt)*) => ({
        $crate::print!(concat!($fmt, "\n"), $($arg)*);
    });
}
