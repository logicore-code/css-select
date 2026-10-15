// A low-level byte cursor over a selector string.
//
// The parser drives this cursor directly instead of going through a separate
// token stream: selector syntax is small and whitespace is semantically
// significant, so a hand-written cursor gives us full control over the
// descendant-combinator rules (collapsing runs of whitespace into one).

/// Position in the source (1-based line/column for error messages).
pub struct Pos {
  offset : Int
  line : Int
  col : Int
} derive(Show, Debug)

/// An error raised while parsing a selector.
pub struct ParseError {
  pos : Pos
  message : String
} derive(Show, Debug)

// Public constructors and getters -------------------------------------------------

pub fn ParseError::new(pos : Pos, message : String) -> ParseError {
  { pos, message }
}

pub fn ParseError::position(err : ParseError) -> Pos { err.pos }

pub fn ParseError::reason(err : ParseError) -> String { err.message }

/// Convert the error into a human-readable one-liner.
pub fn ParseError::to_string(err : ParseError) -> String {
  "parse error at line {err.pos.line}, col {err.pos.col}: {err.message}"
}

// Small byte predicates -----------------------------------------------------------

fn is_ws_byte(c : UInt16) -> Bool {
  c == ' ' || c == '\t' || c == '\n' || c == '\r' || c == '\u{000C}'
}

fn is_ident_start_byte(c : UInt16) -> Bool {
  (c >= 'a' && c <= 'z') || (c >= 'A' && c <= 'Z') || c == '_' || c >= 0x80
}

fn is_ident_byte(c : UInt16) -> Bool {
  is_ident_start_byte(c) || (c >= '0' && c <= '9') || c == '-'
}

/// A Char constant as UInt16, for comparing against source bytes.
fn ch(c : Char) -> UInt16 { c.to_int().to_uint16() }

// Cursor -------------------------------------------------------------------------

struct Cursor {
  src : String
  mut pos : Int
  mut line : Int
  mut col : Int
}

fn Cursor::create(src : String) -> Cursor {
  { src, pos: 0, line: 1, col: 1 }
}

fn Cursor::eof(self : Cursor) -> Bool { self.pos >= self.src.length() }

fn Cursor::pos(self : Cursor) -> Pos { { offset: self.pos, line: self.line, col: self.col } }

/// Peek the current byte without consuming it.
fn Cursor::peek_byte(self : Cursor) -> UInt16? {
  if self.eof() {
    None
  } else {
    Some(self.src[self.pos])
  }
}

/// Consume and return the next byte.
fn Cursor::bump(self : Cursor) -> UInt16? {
  let cur = self.peek_byte()
  match cur {
    None => None
    Some(c) => {
      self.pos += 1
      if c == ch('\n') {
        self.line += 1
        self.col = 1
      } else {
        self.col += 1
      }
      Some(c)
    }
  }
}

/// Require that the next byte is `c`, consuming it.
fn Cursor::expect_byte(self : Cursor, c : Char) -> Result[Unit, ParseError] {
  let cur = self.peek_byte()
  if cur.is_some() && cur.unwrap() == ch(c) {
    let _ = self.bump()
    Ok(())
  } else {
    let p = self.pos()
    Err(ParseError::new(p, "expected '{c}'"))
  }
}

/// Skip ASCII whitespace runs. Returns true if at least one byte was consumed.
fn Cursor::skip_ws(self : Cursor) -> Bool {
  let mut consumed = false
  while true {
    let cur = self.peek_byte()
    if cur.is_none() {
      break
    }
    let c = cur.unwrap()
    if is_ws_byte(c) {
      let _ = self.bump()
      consumed = true
    } else {
      break
    }
  }
  consumed
}

/// Read a CSS identifier.
fn Cursor::read_ident(self : Cursor) -> String {
  let sb = StringBuilder()
  while true {
    let cur = self.peek_byte()
    if cur.is_none() {
      break
    }
    let c = cur.unwrap()
    if is_ident_byte(c) {
      sb.write_char(c.to_char().unwrap())
      let _ = self.bump()
    } else {
      break
    }
  }
  sb.to_string()
}

/// Read an unsigned integer. Returns (value, found).
fn Cursor::read_uint(self : Cursor) -> (Int, Bool) {
  let mut value = 0
  let mut found = false
  while true {
    let cur = self.peek_byte()
    if cur.is_none() {
      break
    }
    let c = cur.unwrap()
    if c >= ch('0') && c <= ch('9') {
      value = value * 10 + (c - ch('0')).to_int()
      let _ = self.bump()
      found = true
    } else {
      break
    }
  }
  (value, found)
}

/// Read a quoted string ("..." or '...'), without the surrounding quotes.
fn Cursor::read_quoted(self : Cursor, quote : Char) -> Result[String, ParseError] {
  let _ = self.bump() // opening quote
  let sb = StringBuilder()
  while true {
    let cur = self.bump()
    if cur.is_none() {
      let p = self.pos()
      return Err(ParseError::new(p, "unterminated string"))
    }
    let b = cur.unwrap()
    if b == ch(quote) {
      break
    } else if b == ch('\\') {
      let esc = self.bump()
      if esc.is_none() {
        let p = self.pos()
        return Err(ParseError::new(p, "unterminated escape"))
      }
      sb.write_char(esc.unwrap().to_char().unwrap())
    } else {
      sb.write_char(b.to_char().unwrap())
    }
  }
  Ok(sb.to_string())
}
