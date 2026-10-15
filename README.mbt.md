# css-select

A CSS selector parser and matching engine for MoonBit, implementing the W3C Selectors Level 3 spec.

## Features

- Full selector parser: type, universal, class, ID, attribute (7 operators, case-insensitive flag), pseudo-classes
- Combinators: descendant, child, adjacent sibling, general sibling
- Pseudo-classes: `:root`, `:empty`, `:first-child`, `:last-child`, `:nth-child(an+b | odd | even)`, `:nth-of-type`, `:not()`, `:is()`, `:lang()`
- Generic matching engine over any tree implementing the `SelectableNode` trait
- Built-in in-memory `DomNode` reference implementation
- No dependencies

## Usage

```moonbit
let list = parse_selectors("ul#nav li.item.active")?
let matches = matches_list(node, list)
```

## Tests

```bash
moon test
```

## License

Apache-2.0
