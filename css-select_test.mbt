// Whitebox tests for the selector parser.

test "parse simple type selector" {
  let r = parse_selectors("div")
  assert_true(r.is_ok())
  let list = r.unwrap()
  assert_eq(list.length(), 1)
}

test "parse class id and attribute" {
  let r = parse_selectors("div#nav.active[href^='/']")
  assert_true(r.is_ok())
}

test "parse combinators" {
  let r = parse_selectors("div > p.cls span")
  assert_true(r.is_ok())
  let c = r.unwrap()[0]
  // subject is span; two ancestors.
  assert_eq(c.ancestors.length(), 2)
}

test "parse selector list" {
  let r = parse_selectors("div, p, span.foo")
  assert_true(r.is_ok())
  assert_eq(r.unwrap().length(), 3)
}

test "parse nth-child" {
  let r = parse_selectors("li:nth-child(2n+1)")
  assert_true(r.is_ok())
}

test "parse nth keywords" {
  assert_true(parse_selectors("li:nth-child(odd)").is_ok())
  assert_true(parse_selectors("li:nth-child(even)").is_ok())
  assert_true(parse_selectors("li:nth-child(-n+3)").is_ok())
}

test "parse not and is" {
  assert_true(parse_selectors("div:not(.hidden)").is_ok())
  assert_true(parse_selectors("div:is(.a, .b) > p").is_ok())
}

test "reject empty selector" {
  assert_true(parse_selectors("   ").is_err())
}

test "reject trailing combinator" {
  assert_true(parse_selectors("div > ").is_err())
}
