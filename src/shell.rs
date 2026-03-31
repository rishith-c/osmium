use crate::{fs, input, print, println, python, time};

const MAX_PATH_LEN: usize = 64;
const MAX_DEPTH: usize = 16;

pub fn run() -> ! {
    let mut cwd_buf = [0u8; MAX_PATH_LEN];
    cwd_buf[0] = b'/';
    let mut cwd_len = 1;
    let mut line_buf = [0u8; 192];

    loop {
        let cwd = core::str::from_utf8(&cwd_buf[..cwd_len]).unwrap_or("/");
        let mut prompt_buf = [0u8; MAX_PATH_LEN + 12];
        let prompt = make_prompt(cwd, &mut prompt_buf);
        let line = input::read_line(prompt, &mut line_buf).trim();

        if line.is_empty() {
            continue;
        }

        if line == "help" {
            print_help();
            continue;
        }

        if line == "clear" {
            print!("\x1b[2J\x1b[H");
            continue;
        }

        if line == "pwd" {
            println!("{}", cwd);
            continue;
        }

        if line == "python" {
            python::repl();
            continue;
        }

        if let Some(rest) = line.strip_prefix("echo ") {
            println!("{}", rest);
            continue;
        }

        if line == "uname" {
            println!("Osmium");
            continue;
        }

        if line == "uname -a" {
            println!("Osmium pi4 aarch64 bare-metal");
            continue;
        }

        if line == "weather" {
            if let Some(contents) = fs::read_file("/etc/weather.txt") {
                println!("{}", contents);
            } else {
                println!("no cached weather data");
            }
            continue;
        }

        if let Some(rest) = line.strip_prefix("weather set ") {
            match fs::write_file("/etc/weather.txt", rest) {
                Ok(()) => println!("weather cache updated"),
                Err(_) => println!("failed to update weather cache"),
            }
            continue;
        }

        if handle_date(line) {
            continue;
        }

        if let Some(path) = line.strip_prefix("cd ") {
            let mut resolved_buf = [0u8; MAX_PATH_LEN];
            match resolve_path(cwd, path.trim(), &mut resolved_buf) {
                Ok(resolved) if fs::is_dir(resolved) => {
                    cwd_len = copy_string(resolved.as_bytes(), &mut cwd_buf);
                }
                Ok(_) => println!("cd: no such directory"),
                Err(err) => println!("cd: {}", err),
            }
            continue;
        }

        if line == "ls" {
            list_dir(cwd);
            continue;
        }

        if let Some(path) = line.strip_prefix("ls ") {
            let mut resolved_buf = [0u8; MAX_PATH_LEN];
            match resolve_path(cwd, path.trim(), &mut resolved_buf) {
                Ok(resolved) => {
                    if fs::is_file(resolved) {
                        println!("{}", fs::basename(resolved));
                    } else {
                        list_dir(resolved);
                    }
                }
                Err(err) => println!("ls: {}", err),
            }
            continue;
        }

        if let Some(path) = line.strip_prefix("cat ") {
            let mut resolved_buf = [0u8; MAX_PATH_LEN];
            match resolve_path(cwd, path.trim(), &mut resolved_buf) {
                Ok(resolved) => match fs::read_file(resolved) {
                    Some(contents) => println!("{}", contents),
                    None => println!("cat: file not found"),
                },
                Err(err) => println!("cat: {}", err),
            }
            continue;
        }

        if let Some(path) = line.strip_prefix("mkdir ") {
            let mut resolved_buf = [0u8; MAX_PATH_LEN];
            match resolve_path(cwd, path.trim(), &mut resolved_buf).mkdir_from_result() {
                Ok(()) => println!("directory created"),
                Err(err) => println!("mkdir: {}", err),
            }
            continue;
        }

        if let Some(path) = line.strip_prefix("touch ") {
            let mut resolved_buf = [0u8; MAX_PATH_LEN];
            match resolve_path(cwd, path.trim(), &mut resolved_buf).touch_from_result() {
                Ok(()) => println!("file created"),
                Err(err) => println!("touch: {}", err),
            }
            continue;
        }

        if let Some(rest) = line.strip_prefix("write ") {
            match split_two(rest) {
                Some((path, contents)) => {
                    let mut resolved_buf = [0u8; MAX_PATH_LEN];
                    match resolve_path(cwd, path, &mut resolved_buf)
                        .and_then(|resolved| fs::write_file(resolved, contents).map_err(fs_error))
                    {
                        Ok(()) => println!("file updated"),
                        Err(err) => println!("write: {}", err),
                    }
                }
                None => println!("write: usage: write <path> <text>"),
            }
            continue;
        }

        println!("{}: command not found", line);
    }
}

fn handle_date(line: &str) -> bool {
    if line == "date" {
        let mut buffer = [0u8; 32];
        println!("{}", time::format_now(&mut buffer));
        if !time::is_synced() {
            println!("clock unsynced; use `date set <unix_seconds>`");
        }
        return true;
    }

    if line == "date +%s" {
        println!("{}", time::unix_seconds());
        return true;
    }

    if let Some(value) = line.strip_prefix("date set ") {
        match value.trim().parse::<i64>() {
            Ok(seconds) => {
                time::set_unix_seconds(seconds);
                println!("clock updated");
            }
            Err(_) => println!("date: expected unix seconds"),
        }
        return true;
    }

    false
}

fn list_dir(path: &str) {
    match fs::list_dir(path, |name, is_dir| {
        if is_dir {
            println!("{}/", name);
        } else {
            println!("{}", name);
        }
    }) {
        Ok(()) => {}
        Err(_) => println!("ls: no such directory"),
    }
}

fn make_prompt<'a>(cwd: &str, dest: &'a mut [u8]) -> &'a str {
    let prefix = b"osmium:";
    let suffix = b"$ ";
    let mut len = 0;

    for byte in prefix {
        dest[len] = *byte;
        len += 1;
    }
    for byte in cwd.as_bytes() {
        dest[len] = *byte;
        len += 1;
    }
    for byte in suffix {
        dest[len] = *byte;
        len += 1;
    }

    core::str::from_utf8(&dest[..len]).unwrap_or("osmium:/$ ")
}

fn copy_string(src: &[u8], dest: &mut [u8]) -> usize {
    let len = src.len().min(dest.len());
    let mut index = 0;
    while index < len {
        dest[index] = src[index];
        index += 1;
    }
    len
}

fn split_two(input: &str) -> Option<(&str, &str)> {
    let trimmed = input.trim();
    let space = trimmed.find(' ')?;
    let (first, second) = trimmed.split_at(space);
    Some((first, second.trim_start()))
}

fn resolve_path<'a>(
    cwd: &str,
    input: &str,
    out: &'a mut [u8; MAX_PATH_LEN],
) -> Result<&'a str, &'static str> {
    if input.is_empty() {
        return Err("missing path");
    }

    let mut checkpoints = [1usize; MAX_DEPTH];
    let mut depth = 0usize;
    let mut len = 1usize;
    out[0] = b'/';

    if !input.starts_with('/') {
        append_path_segments(cwd, out, &mut len, &mut checkpoints, &mut depth)?;
    }
    append_path_segments(input, out, &mut len, &mut checkpoints, &mut depth)?;

    if len > 1 && out[len - 1] == b'/' {
        len -= 1;
    }

    core::str::from_utf8(&out[..len]).map_err(|_| "invalid path")
}

fn append_path_segments(
    path: &str,
    out: &mut [u8; MAX_PATH_LEN],
    len: &mut usize,
    checkpoints: &mut [usize; MAX_DEPTH],
    depth: &mut usize,
) -> Result<(), &'static str> {
    for segment in path.split('/') {
        if segment.is_empty() || segment == "." {
            continue;
        }
        if segment == ".." {
            if *depth > 0 {
                *depth -= 1;
                *len = checkpoints[*depth];
            } else {
                *len = 1;
            }
            continue;
        }
        if *depth >= MAX_DEPTH {
            return Err("path too deep");
        }
        if *len > 1 {
            out[*len] = b'/';
            *len += 1;
        }
        if *len + segment.len() > out.len() {
            return Err("path too long");
        }
        for byte in segment.as_bytes() {
            out[*len] = *byte;
            *len += 1;
        }
        checkpoints[*depth] = *len;
        *depth += 1;
    }
    Ok(())
}

fn fs_error(err: fs::FsError) -> &'static str {
    match err {
        fs::FsError::AlreadyExists => "already exists",
        fs::FsError::InvalidPath => "invalid path",
        fs::FsError::NoSpace => "out of space",
        fs::FsError::NotFound => "not found",
        fs::FsError::ParentMissing => "parent directory missing",
    }
}

fn print_help() {
    println!("Available commands:");
    println!("  help");
    println!("  clear");
    println!("  pwd");
    println!("  cd <path>");
    println!("  ls [path]");
    println!("  cat <file>");
    println!("  echo <text>");
    println!("  mkdir <path>");
    println!("  touch <path>");
    println!("  write <path> <text>");
    println!("  uname [-a]");
    println!("  date");
    println!("  date +%s");
    println!("  date set <unix_seconds>");
    println!("  weather");
    println!("  weather set <text>");
    println!("  python");
}

trait FsCreate {
    fn mkdir_from_result(self) -> Result<(), &'static str>;
    fn touch_from_result(self) -> Result<(), &'static str>;
}

impl FsCreate for Result<&str, &'static str> {
    fn mkdir_from_result(self) -> Result<(), &'static str> {
        match self {
            Ok(path) => fs::mkdir(path).map_err(fs_error),
            Err(err) => Err(err),
        }
    }

    fn touch_from_result(self) -> Result<(), &'static str> {
        match self {
            Ok(path) => fs::touch(path).map_err(fs_error),
            Err(err) => Err(err),
        }
    }
}
