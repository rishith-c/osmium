use core::cell::UnsafeCell;
use core::str;

const MAX_DIRS: usize = 16;
const MAX_FILES: usize = 32;
const MAX_PATH_LEN: usize = 64;
const MAX_FILE_LEN: usize = 384;

#[derive(Clone, Copy)]
struct DirEntry {
    used: bool,
    path_len: usize,
    path: [u8; MAX_PATH_LEN],
}

impl DirEntry {
    const fn empty() -> Self {
        Self {
            used: false,
            path_len: 0,
            path: [0; MAX_PATH_LEN],
        }
    }

    fn path(&self) -> &str {
        unsafe { str::from_utf8_unchecked(&self.path[..self.path_len]) }
    }
}

#[derive(Clone, Copy)]
struct FileEntry {
    used: bool,
    path_len: usize,
    data_len: usize,
    path: [u8; MAX_PATH_LEN],
    data: [u8; MAX_FILE_LEN],
}

impl FileEntry {
    const fn empty() -> Self {
        Self {
            used: false,
            path_len: 0,
            data_len: 0,
            path: [0; MAX_PATH_LEN],
            data: [0; MAX_FILE_LEN],
        }
    }

    fn path(&self) -> &str {
        unsafe { str::from_utf8_unchecked(&self.path[..self.path_len]) }
    }

    fn data_static(&self) -> &'static str {
        let text = unsafe { str::from_utf8_unchecked(&self.data[..self.data_len]) };
        unsafe { core::mem::transmute::<&str, &'static str>(text) }
    }
}

pub enum FsError {
    AlreadyExists,
    InvalidPath,
    NoSpace,
    NotFound,
    ParentMissing,
}

struct FileSystem {
    dirs: [DirEntry; MAX_DIRS],
    files: [FileEntry; MAX_FILES],
}

impl FileSystem {
    const fn new() -> Self {
        Self {
            dirs: [DirEntry::empty(); MAX_DIRS],
            files: [FileEntry::empty(); MAX_FILES],
        }
    }

    fn reset(&mut self) {
        *self = Self::new();
        let _ = self.add_dir("/bin");
        let _ = self.add_dir("/etc");
        let _ = self.add_dir("/home");
        let _ = self.add_dir("/tmp");
        let _ = self.write_file(
            "/etc/motd",
            "Welcome to Osmium.\nMac-style command names are available over UART.",
        );
        let _ = self.write_file(
            "/etc/weather.txt",
            "San Francisco: 68F, clear skies (cached sample)",
        );
        let _ = self.write_file(
            "/home/readme.txt",
            "Try: help, ls, cat /etc/motd, date, weather, python",
        );
    }

    fn dir_exists(&self, path: &str) -> bool {
        path == "/"
            || self
                .dirs
                .iter()
                .any(|entry| entry.used && entry.path() == path)
    }

    fn file_exists(&self, path: &str) -> bool {
        self.files
            .iter()
            .any(|entry| entry.used && entry.path() == path)
    }

    fn add_dir(&mut self, path: &str) -> Result<(), FsError> {
        if !is_absolute(path) || path.len() > MAX_PATH_LEN || path == "/" {
            return Err(FsError::InvalidPath);
        }
        if self.dir_exists(path) || self.file_exists(path) {
            return Err(FsError::AlreadyExists);
        }
        if !self.dir_exists(parent_dir(path)) {
            return Err(FsError::ParentMissing);
        }

        let slot = self
            .dirs
            .iter_mut()
            .find(|entry| !entry.used)
            .ok_or(FsError::NoSpace)?;

        slot.used = true;
        slot.path_len = copy_bytes(path.as_bytes(), &mut slot.path)?;
        Ok(())
    }

    fn touch(&mut self, path: &str) -> Result<(), FsError> {
        self.write_file(path, "")
    }

    fn write_file(&mut self, path: &str, contents: &str) -> Result<(), FsError> {
        if !is_absolute(path) || path.len() > MAX_PATH_LEN || contents.len() > MAX_FILE_LEN {
            return Err(FsError::InvalidPath);
        }
        if !self.dir_exists(parent_dir(path)) {
            return Err(FsError::ParentMissing);
        }
        if self.dir_exists(path) {
            return Err(FsError::AlreadyExists);
        }

        if let Some(entry) = self
            .files
            .iter_mut()
            .find(|entry| entry.used && entry.path() == path)
        {
            entry.data_len = copy_bytes(contents.as_bytes(), &mut entry.data)?;
            return Ok(());
        }

        let slot = self
            .files
            .iter_mut()
            .find(|entry| !entry.used)
            .ok_or(FsError::NoSpace)?;

        slot.used = true;
        slot.path_len = copy_bytes(path.as_bytes(), &mut slot.path)?;
        slot.data_len = copy_bytes(contents.as_bytes(), &mut slot.data)?;
        Ok(())
    }

    fn read_file(&self, path: &str) -> Option<&'static str> {
        self.files
            .iter()
            .find(|entry| entry.used && entry.path() == path)
            .map(|entry| entry.data_static())
    }
}

struct GlobalFs(UnsafeCell<FileSystem>);

unsafe impl Sync for GlobalFs {}

static FS: GlobalFs = GlobalFs(UnsafeCell::new(FileSystem::new()));

fn with_fs<R>(f: impl FnOnce(&FileSystem) -> R) -> R {
    unsafe { f(&*FS.0.get()) }
}

fn with_fs_mut<R>(f: impl FnOnce(&mut FileSystem) -> R) -> R {
    unsafe { f(&mut *FS.0.get()) }
}

pub fn init() {
    with_fs_mut(|fs| fs.reset());
}

pub fn is_dir(path: &str) -> bool {
    with_fs(|fs| fs.dir_exists(path))
}

pub fn is_file(path: &str) -> bool {
    with_fs(|fs| fs.file_exists(path))
}

pub fn mkdir(path: &str) -> Result<(), FsError> {
    with_fs_mut(|fs| fs.add_dir(path))
}

pub fn touch(path: &str) -> Result<(), FsError> {
    with_fs_mut(|fs| fs.touch(path))
}

pub fn write_file(path: &str, contents: &str) -> Result<(), FsError> {
    with_fs_mut(|fs| fs.write_file(path, contents))
}

pub fn read_file(path: &str) -> Option<&'static str> {
    with_fs(|fs| fs.read_file(path))
}

pub fn list_dir<F>(dir: &str, mut visitor: F) -> Result<(), FsError>
where
    F: FnMut(&str, bool),
{
    if !is_dir(dir) {
        return Err(FsError::NotFound);
    }

    with_fs(|fs| {
        for entry in fs.dirs.iter().filter(|entry| entry.used) {
            if let Some(name) = immediate_child_name(dir, entry.path()) {
                visitor(name, true);
            }
        }

        for entry in fs.files.iter().filter(|entry| entry.used) {
            if let Some(name) = immediate_child_name(dir, entry.path()) {
                visitor(name, false);
            }
        }
    });

    Ok(())
}

pub fn basename(path: &str) -> &str {
    if path == "/" {
        return "/";
    }
    path.rsplit('/').next().unwrap_or(path)
}

fn immediate_child_name<'a>(parent: &str, child: &'a str) -> Option<&'a str> {
    if parent == "/" {
        let rest = child.strip_prefix('/')?;
        if rest.is_empty() || rest.contains('/') {
            return None;
        }
        return Some(rest);
    }

    let prefix = if parent.ends_with('/') {
        parent
    } else {
        return child
            .strip_prefix(parent)?
            .strip_prefix('/')
            .and_then(|rest| {
                if rest.is_empty() || rest.contains('/') {
                    None
                } else {
                    Some(rest)
                }
            });
    };

    child
        .strip_prefix(prefix)?
        .strip_prefix('/')
        .and_then(|rest| {
            if rest.is_empty() || rest.contains('/') {
                None
            } else {
                Some(rest)
            }
        })
}

fn parent_dir(path: &str) -> &str {
    match path.rfind('/') {
        Some(0) => "/",
        Some(index) => &path[..index],
        None => "/",
    }
}

fn is_absolute(path: &str) -> bool {
    path.starts_with('/')
}

fn copy_bytes(src: &[u8], dest: &mut [u8]) -> Result<usize, FsError> {
    if src.len() > dest.len() {
        return Err(FsError::NoSpace);
    }

    let mut index = 0;
    while index < src.len() {
        dest[index] = src[index];
        index += 1;
    }
    while index < dest.len() {
        dest[index] = 0;
        index += 1;
    }

    Ok(src.len())
}
