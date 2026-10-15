# css-select

A CSS selector parser and matching engine for MoonBit, implementing W3C Selectors Level 3.

## What it does

Takes a selector string like `div#nav > li.item.active:nth-child(2n+1)` and a tree of nodes, and tells you which nodes match. The parser is a hand-written recursive descent parser; the matcher is generic over any tree that implements the `SelectableNode` trait, so you can point it at your own DOM, an HTML parser's AST, or a WASM DOM wrapper.

## Supported selectors

| Category | Syntax |
|---|---|
| Type | `div`, `span` |
| Universal | `*` |
| ID | `#nav` |
| Class | `.active`, `.a.b` |
| Attribute | `[href]`, `[href="/"]`, `[href^="/"]`, `[href$="home"]`, `[href*="hom"]`, `[rel~="help"]`, `[lang|="en"]`, `[href="/" i]` |
| Combinators | ` ` (descendant), `>` (child), `+` (adjacent sibling), `~` (general sibling) |
| Pseudo-classes | `:root`, `:empty`, `:first-child`, `:last-child`, `:nth-child(an+b)`, `:nth-of-type(an+b)`, `:not()`, `:is()`, `:lang()` |
| Lists | `div, p, span` |

`nth-child` accepts `odd`, `even`, `2n+1`, `-n+3`, etc.

## Quick start

```moonbit
let list = parse_selectors("ul#nav li.item.active")?
if matches_list(node, list) {
  println("matched!")
}
```

## CLI

```bash
moon run cmd/main -- "ul li.item.active"
moon run cmd/main -- "div p" "div\n  p\n    span"
```

## Tests

```bash
moon test
```

23 tests covering parser errors, combinators, attribute operators, nth-child arithmetic, and pseudo-classes.

## License

Apache-2.0
