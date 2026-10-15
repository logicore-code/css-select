// Recursive-descent parser for CSS selectors.
//
// Grammar (simplified, Selectors Level 3 with a few Level 4 additions):
//
//   selector_list  = complex ( "," complex )*
//   complex        = compound ( combinator compound )*
//   combinator     = ws? ( ">" | "+" | "~" ) ws? | ws
//   compound       = [ type | "*" ] ( simple )*
//   simple         = "." ident | "#" ident | "[" attr "]" | ":" pseudo

/// Parse a full selector list, e.g. `div, p.cls`.
pub fn parse_selectors(src : String) -> Result[SelectorList, ParseError] {
  let cur = Cursor::create(src)
  let out : Array[ComplexSelector] = []
  let _ = cur.skip_ws()
  if cur.eof() {
    let p = cur.pos()
    return Err(ParseError::new(p, "empty selector"))
  }
  while true {
    match parse_complex(cur) {
      Err(e) => return Err(e)
      Ok(complex) => out.push(complex)
    }
    let _ = cur.skip_ws()
    if cur.eof() {
      break
    }
    let c = cur.peek_byte()
    if c.is_some() && c.unwrap() == ch(',') {
      let _ = cur.bump()
      let _ = cur.skip_ws()
      if cur.eof() {
        let p = cur.pos()
        return Err(ParseError::new(p, "unexpected end after ','"))
      }
    } else {
      let p = cur.pos()
      return Err(ParseError::new(p, "expected ',' or end of selector"))
    }
  }
  Ok(out)
}

// Complex selector ----------------------------------------------------------------

fn parse_complex(cur : Cursor) -> Result[ComplexSelector, ParseError] {
  let compounds : Array[CompoundSelector] = []
  let combinators : Array[Combinator] = []

  match parse_compound(cur) {
    Err(e) => return Err(e)
    Ok(first) => compounds.push(first)
  }

  while true {
    let had_ws = cur.skip_ws()
    if cur.eof() {
      break
    }
    let c = cur.peek_byte().unwrap()
    let mut comb : Combinator = Descendant
    if c == ch('>') {
      let _ = cur.bump()
      comb = Child
      let _ = cur.skip_ws()
    } else if c == ch('+') {
      let _ = cur.bump()
      comb = AdjacentSibling
      let _ = cur.skip_ws()
    } else if c == ch('~') {
      let _ = cur.bump()
      comb = GeneralSibling
      let _ = cur.skip_ws()
    } else if had_ws {
      comb = Descendant
    } else {
      break
    }
    if cur.eof() {
      let p = cur.pos()
      return Err(ParseError::new(p, "unexpected end after combinator"))
    }
    match parse_compound(cur) {
      Err(e) => return Err(e)
      Ok(next) => {
        compounds.push(next)
        combinators.push(comb)
      }
    }
  }

  // subject = last compound; ancestors built right-to-left.
  let n = compounds.length()
  let subject = compounds[n - 1]
  let ancestors : Array[(Combinator, CompoundSelector)] = []
  let mut i = n - 1
  while i >= 1 {
    ancestors.push((combinators[i - 1], compounds[i - 1]))
    i -= 1
  }
  Ok({ subject, ancestors })
}

// Compound selector ----------------------------------------------------------------

fn parse_compound(cur : Cursor) -> Result[CompoundSelector, ParseError] {
  let simples : Array[SimpleSelector] = []

  let c = cur.peek_byte()
  if c.is_none() {
    let p = cur.pos()
    return Err(ParseError::new(p, "expected a selector"))
  }
  let fb = c.unwrap()
  if fb == ch('*') {
    let _ = cur.bump()
    simples.push(Universal)
  } else if is_ident_start_byte(fb) {
    let name = cur.read_ident()
    simples.push(Type(name))
  } else if fb != ch('.') && fb != ch('#') && fb != ch('[') && fb != ch(':') {
    let p = cur.pos()
    return Err(ParseError::new(p, "expected a selector"))
  }

  while true {
    let peek = cur.peek_byte()
    if peek.is_none() {
      break
    }
    let b = peek.unwrap()
    if b == ch('.') {
      let _ = cur.bump()
      let name = cur.read_ident()
      if name.length() == 0 {
        let p = cur.pos()
        return Err(ParseError::new(p, "expected class name after '.'"))
      }
      simples.push(Class(name))
    } else if b == ch('#') {
      let _ = cur.bump()
      let name = cur.read_ident()
      if name.length() == 0 {
        let p = cur.pos()
        return Err(ParseError::new(p, "expected id after '#'"))
      }
      simples.push(Id(name))
    } else if b == ch('[') {
      let _ = cur.bump()
      match parse_attribute_selector(cur) {
        Err(e) => return Err(e)
        Ok(attr) => simples.push(attr)
      }
    } else if b == ch(':') {
      let _ = cur.bump()
      let nxt = cur.peek_byte()
      if nxt.is_some() && nxt.unwrap() == ch(':') {
        let p = cur.pos()
        return Err(ParseError::new(p, "pseudo-elements are not supported"))
      }
      match parse_pseudo(cur) {
        Err(e) => return Err(e)
        Ok(pseudo) => simples.push(pseudo)
      }
    } else {
      break
    }
  }

  if simples.length() == 0 {
    let p = cur.pos()
    return Err(ParseError::new(p, "expected a selector"))
  }
  Ok({ simples })
}

// Attribute selector ----------------------------------------------------------------

fn parse_attribute_selector(cur : Cursor) -> Result[SimpleSelector, ParseError] {
  let _ = cur.skip_ws()
  let name = cur.read_ident()
  if name.length() == 0 {
    let p = cur.pos()
    return Err(ParseError::new(p, "expected attribute name"))
  }
  let _ = cur.skip_ws()
  let close = cur.peek_byte()
  if close.is_some() && close.unwrap() == ch(']') {
    let _ = cur.bump()
    return Ok(Attr({ name, op: Exists, value: "", icase: false }))
  }
  let ob = cur.peek_byte()
  if ob.is_none() {
    let p = cur.pos()
    return Err(ParseError::new(p, "unterminated attribute selector"))
  }
  let opb = ob.unwrap()
  let mut op : AttributeOp = Equals
  if opb == ch('=') {
    let _ = cur.bump()
    op = Equals
  } else if opb == ch('~') || opb == ch('|') || opb == ch('^') || opb == ch('$') || opb == ch('*') {
    let _ = cur.bump()
    match cur.expect_byte('=') {
      Err(e) => return Err(e)
      Ok(_) => ()
    }
    if opb == ch('~') {
      op = Includes
    } else if opb == ch('|') {
      op = DashMatch
    } else if opb == ch('^') {
      op = Prefix
    } else if opb == ch('$') {
      op = Suffix
    } else {
      op = Substring
    }
  } else {
    let p = cur.pos()
    return Err(ParseError::new(p, "expected ']' or an attribute operator"))
  }
  let _ = cur.skip_ws()
  let vb = cur.peek_byte()
  if vb.is_none() {
    let p = cur.pos()
    return Err(ParseError::new(p, "expected attribute value"))
  }
  let vbb = vb.unwrap()
  let mut value : String = ""
  if vbb == ch('"') || vbb == ch('\'') {
    match cur.read_quoted(vbb.to_char().unwrap()) {
      Err(e) => return Err(e)
      Ok(v) => value = v
    }
  } else if is_ident_start_byte(vbb) || vbb == ch('-') {
    value = cur.read_ident()
  } else {
    let p = cur.pos()
    return Err(ParseError::new(p, "expected attribute value"))
  }
  let _ = cur.skip_ws()
  let mut icase = false
  let flag = cur.peek_byte()
  if flag.is_some() {
    let fb = flag.unwrap()
    if fb == ch('i') || fb == ch('I') {
      let _ = cur.bump()
      icase = true
      let _ = cur.skip_ws()
    } else if fb == ch('s') || fb == ch('S') {
      let _ = cur.bump()
      let _ = cur.skip_ws()
    }
  }
  match cur.expect_byte(']') {
    Err(e) => return Err(e)
    Ok(_) => ()
  }
  Ok(Attr({ name, op, value, icase }))
}

// Pseudo-class ----------------------------------------------------------------------

fn parse_pseudo(cur : Cursor) -> Result[SimpleSelector, ParseError] {
  let name = cur.read_ident().to_lower()
  let peek = cur.peek_byte()
  if peek.is_none() || peek.unwrap() != ch('(') {
    return simple_pseudo(name)
  }
  let _ = cur.bump() // '('
  let _ = cur.skip_ws()

  let mut result : SimpleSelector = Universal
  match name {
    "nth-child" => {
      match parse_nth(cur) {
        Err(e) => return Err(e)
        Ok(n) => result = Pseudo(NthChild(n))
      }
    }
    "nth-last-child" => {
      match parse_nth(cur) {
        Err(e) => return Err(e)
        Ok(n) => result = Pseudo(NthLastChild(n))
      }
    }
    "nth-of-type" => {
      match parse_nth(cur) {
        Err(e) => return Err(e)
        Ok(n) => result = Pseudo(NthOfType(n))
      }
    }
    "nth-last-of-type" => {
      match parse_nth(cur) {
        Err(e) => return Err(e)
        Ok(n) => result = Pseudo(NthLastOfType(n))
      }
    }
    "not" => {
      match parse_selectors_until_close(cur) {
        Err(e) => return Err(e)
        Ok(inner) => result = Pseudo(Not(inner))
      }
    }
    "is" => {
      match parse_selectors_until_close(cur) {
        Err(e) => return Err(e)
        Ok(inner) => result = Pseudo(Is(inner))
      }
    }
    "lang" => {
      let _ = cur.skip_ws()
      let lb = cur.peek_byte()
      if lb.is_none() {
        let p = cur.pos()
        return Err(ParseError::new(p, "expected language code"))
      }
      let lbb = lb.unwrap()
      let mut lang : String = ""
      if lbb == ch('"') || lbb == ch('\'') {
        match cur.read_quoted(lbb.to_char().unwrap()) {
          Err(e) => return Err(e)
          Ok(v) => lang = v
        }
      } else {
        lang = cur.read_ident()
      }
      let _ = cur.skip_ws()
      result = Pseudo(Lang(lang.to_lower()))
    }
    _ => {
      let p = cur.pos()
      return Err(ParseError::new(p, "unsupported pseudo-class ':{name}'"))
    }
  }
  match cur.expect_byte(')') {
    Err(e) => return Err(e)
    Ok(_) => ()
  }
  Ok(result)
}

fn simple_pseudo(name : String) -> Result[SimpleSelector, ParseError] {
  let pseudo = match name {
    "root" => Root
    "empty" => Empty
    "first-child" => FirstChild
    "last-child" => LastChild
    "only-child" => OnlyChild
    "first-of-type" => FirstOfType
    "last-of-type" => LastOfType
    "only-of-type" => OnlyOfType
    "enabled" => Enabled
    "disabled" => Disabled
    "checked" => Checked
    "focus" => Focus
    "hover" => Hover
    _ => {
      return Err(ParseError::new(
        Pos::{ offset: 0, line: 0, col: 0 },
        "unsupported pseudo-class ':{name}'",
      ))
    }
  }
  Ok(Pseudo(pseudo))
}

/// Parse a selector list inside `:not(...)` / `:is(...)`, stopping at ')'.
fn parse_selectors_until_close(cur : Cursor) -> Result[SelectorList, ParseError] {
  let out : Array[ComplexSelector] = []
  while true {
    match parse_complex(cur) {
      Err(e) => return Err(e)
      Ok(c) => out.push(c)
    }
    let _ = cur.skip_ws()
    let c = cur.peek_byte()
    if c.is_some() && c.unwrap() == ch(',') {
      let _ = cur.bump()
      let _ = cur.skip_ws()
    } else {
      break
    }
  }
  Ok(out)
}

// An+B ------------------------------------------------------------------------------

/// Parse the argument of :nth-child(), e.g. `odd`, `2n+1`, `-n+3`, `n`, `3`.
fn parse_nth(cur : Cursor) -> Result[Nth, ParseError] {
  let _ = cur.skip_ws()
  let start = cur.peek_byte()
  if start.is_some() && is_ident_start_byte(start.unwrap()) {
    let word = cur.read_ident().to_lower()
    if word == "even" {
      let _ = cur.skip_ws()
      return Ok({ a: 2, b: 0 })
    } else if word == "odd" {
      let _ = cur.skip_ws()
      return Ok({ a: 2, b: 1 })
    } else {
      let p = cur.pos()
      return Err(
        ParseError::new(p, "expected 'even', 'odd', or an+b, got '{word}'"),
      )
    }
  }
  let mut sign = 1
  let sb = cur.peek_byte()
  if sb.is_some() {
    let sbb = sb.unwrap()
    if sbb == ch('+') {
      let _ = cur.bump()
    } else if sbb == ch('-') {
      let _ = cur.bump()
      sign = -1
    }
  }
  let (digits, has_digits) = cur.read_uint()
  let nbt = cur.peek_byte()
  if nbt.is_some() && (nbt.unwrap() == ch('n') || nbt.unwrap() == ch('N')) {
    let _ = cur.bump()
    let a = if has_digits { sign * digits } else { sign }
    let _ = cur.skip_ws()
    match parse_optional_b(cur) {
      Err(e) => return Err(e)
      Ok(b) => Ok({ a, b })
    }
  } else {
    if !has_digits {
      let p = cur.pos()
      return Err(ParseError::new(p, "expected an+b expression"))
    }
    Ok({ a: 0, b: sign * digits })
  }
}

fn parse_optional_b(cur : Cursor) -> Result[Int, ParseError] {
  let sb = cur.peek_byte()
  if sb.is_none() {
    return Ok(0)
  }
  let sbb = sb.unwrap()
  let mut sign : Int = 1
  if sbb == ch('+') {
    let _ = cur.bump()
    sign = 1
  } else if sbb == ch('-') {
    let _ = cur.bump()
    sign = -1
  } else {
    return Ok(0)
  }
  let _ = cur.skip_ws()
  let (digits, has) = cur.read_uint()
  if !has {
    let p = cur.pos()
    return Err(ParseError::new(p, "expected number after sign in an+b"))
  }
  Ok(sign * digits)
}
