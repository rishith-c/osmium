use crate::{input, println};

const MAX_VARS: usize = 16;
const MAX_NAME_LEN: usize = 16;

#[derive(Clone, Copy)]
struct Variable {
    used: bool,
    name_len: usize,
    name: [u8; MAX_NAME_LEN],
    value: i64,
}

impl Variable {
    const fn empty() -> Self {
        Self {
            used: false,
            name_len: 0,
            name: [0; MAX_NAME_LEN],
            value: 0,
        }
    }

    fn matches(&self, candidate: &str) -> bool {
        self.used && self.name() == candidate
    }

    fn name(&self) -> &str {
        unsafe { core::str::from_utf8_unchecked(&self.name[..self.name_len]) }
    }
}

struct Environment {
    vars: [Variable; MAX_VARS],
}

impl Environment {
    const fn new() -> Self {
        Self {
            vars: [Variable::empty(); MAX_VARS],
        }
    }

    fn get(&self, name: &str) -> Option<i64> {
        self.vars
            .iter()
            .find(|var| var.matches(name))
            .map(|var| var.value)
    }

    fn set(&mut self, name: &str, value: i64) -> Result<(), &'static str> {
        if name.is_empty() || name.len() > MAX_NAME_LEN || !is_identifier(name) {
            return Err("invalid variable name");
        }

        if let Some(variable) = self.vars.iter_mut().find(|var| var.matches(name)) {
            variable.value = value;
            return Ok(());
        }

        let variable = self
            .vars
            .iter_mut()
            .find(|var| !var.used)
            .ok_or("variable table full")?;
        variable.used = true;
        variable.name_len = copy_name(name.as_bytes(), &mut variable.name);
        variable.value = value;
        Ok(())
    }
}

pub fn repl() {
    let mut env = Environment::new();
    let mut buffer = [0u8; 128];

    println!("OsmiumPy");
    println!("Supports integer math, variables, and print(expr).");
    println!("Type exit() to leave.");

    loop {
        let line = input::read_line(">>> ", &mut buffer).trim();
        if line.is_empty() {
            continue;
        }
        if line == "exit()" || line == "quit()" {
            println!("leaving python");
            break;
        }

        if let Some(expression) = line
            .strip_prefix("print(")
            .and_then(|rest| rest.strip_suffix(')'))
        {
            match evaluate(expression, &env) {
                Ok(value) => println!("{}", value),
                Err(err) => println!("error: {}", err),
            }
            continue;
        }

        if let Some((name, expression)) = line.split_once('=') {
            let name = name.trim();
            let expression = expression.trim();
            match evaluate(expression, &env).and_then(|value| {
                env.set(name, value)?;
                Ok(value)
            }) {
                Ok(value) => println!("{} = {}", name, value),
                Err(err) => println!("error: {}", err),
            }
            continue;
        }

        match evaluate(line, &env) {
            Ok(value) => println!("{}", value),
            Err(err) => println!("error: {}", err),
        }
    }
}

fn evaluate(source: &str, env: &Environment) -> Result<i64, &'static str> {
    let mut parser = Parser::new(source, env);
    let value = parser.parse_expression()?;
    parser.skip_whitespace();
    if parser.is_finished() {
        Ok(value)
    } else {
        Err("unexpected trailing input")
    }
}

struct Parser<'a> {
    bytes: &'a [u8],
    index: usize,
    env: &'a Environment,
}

impl<'a> Parser<'a> {
    fn new(source: &'a str, env: &'a Environment) -> Self {
        Self {
            bytes: source.as_bytes(),
            index: 0,
            env,
        }
    }

    fn parse_expression(&mut self) -> Result<i64, &'static str> {
        let mut value = self.parse_term()?;
        loop {
            self.skip_whitespace();
            match self.peek() {
                Some(b'+') => {
                    self.index += 1;
                    value += self.parse_term()?;
                }
                Some(b'-') => {
                    self.index += 1;
                    value -= self.parse_term()?;
                }
                _ => return Ok(value),
            }
        }
    }

    fn parse_term(&mut self) -> Result<i64, &'static str> {
        let mut value = self.parse_factor()?;
        loop {
            self.skip_whitespace();
            match self.peek() {
                Some(b'*') => {
                    self.index += 1;
                    value *= self.parse_factor()?;
                }
                Some(b'/') => {
                    self.index += 1;
                    let divisor = self.parse_factor()?;
                    if divisor == 0 {
                        return Err("division by zero");
                    }
                    value /= divisor;
                }
                _ => return Ok(value),
            }
        }
    }

    fn parse_factor(&mut self) -> Result<i64, &'static str> {
        self.skip_whitespace();
        match self.peek() {
            Some(b'(') => {
                self.index += 1;
                let value = self.parse_expression()?;
                self.skip_whitespace();
                if self.peek() == Some(b')') {
                    self.index += 1;
                    Ok(value)
                } else {
                    Err("missing closing parenthesis")
                }
            }
            Some(b'-') => {
                self.index += 1;
                Ok(-self.parse_factor()?)
            }
            Some(b'0'..=b'9') => self.parse_number(),
            Some(b'a'..=b'z') | Some(b'A'..=b'Z') | Some(b'_') => self.parse_identifier(),
            _ => Err("unexpected token"),
        }
    }

    fn parse_number(&mut self) -> Result<i64, &'static str> {
        let start = self.index;
        while matches!(self.peek(), Some(b'0'..=b'9')) {
            self.index += 1;
        }
        let text =
            core::str::from_utf8(&self.bytes[start..self.index]).map_err(|_| "invalid number")?;
        text.parse::<i64>().map_err(|_| "number out of range")
    }

    fn parse_identifier(&mut self) -> Result<i64, &'static str> {
        let start = self.index;
        while matches!(
            self.peek(),
            Some(b'a'..=b'z') | Some(b'A'..=b'Z') | Some(b'0'..=b'9') | Some(b'_')
        ) {
            self.index += 1;
        }

        let name = core::str::from_utf8(&self.bytes[start..self.index])
            .map_err(|_| "invalid identifier")?;
        self.env.get(name).ok_or("unknown variable")
    }

    fn skip_whitespace(&mut self) {
        while matches!(self.peek(), Some(b' ' | b'\t')) {
            self.index += 1;
        }
    }

    fn peek(&self) -> Option<u8> {
        self.bytes.get(self.index).copied()
    }

    fn is_finished(&self) -> bool {
        self.index >= self.bytes.len()
    }
}

fn is_identifier(name: &str) -> bool {
    let mut bytes = name.bytes();
    match bytes.next() {
        Some(b'a'..=b'z') | Some(b'A'..=b'Z') | Some(b'_') => {}
        _ => return false,
    }

    bytes.all(|byte| matches!(byte, b'a'..=b'z' | b'A'..=b'Z' | b'0'..=b'9' | b'_'))
}

fn copy_name(src: &[u8], dest: &mut [u8; MAX_NAME_LEN]) -> usize {
    let mut index = 0;
    while index < src.len() {
        dest[index] = src[index];
        index += 1;
    }
    while index < dest.len() {
        dest[index] = 0;
        index += 1;
    }
    src.len()
}
