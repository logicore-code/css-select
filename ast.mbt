// CSS Selector AST, following the Selectors Level 3 (and common Level 4) model.
//
// A selector list (e.g. `div, p.cls`) is a list of complex selectors.
// Each complex selector describes a subject compound plus a chain of
// ancestor compounds connected by combinators.
//
// Example: `div.main > ul.nav li a`
//   subject        = compound(a)
//   ancestors = [
//     (Descendant, compound(li)),
//     (Child,      compound(ul.nav)),
//     (Descendant, compound(div.main)),
//   ]

/// How two compound selectors are combined in the document tree.
pub enum Combinator {
  /// Descendant: whitespace, e.g. `a b`.
  Descendant
  /// Child: `a > b`.
  Child
  /// Adjacent sibling: `a + b`.
  AdjacentSibling
  /// General sibling: `a ~ b`.
  GeneralSibling
} derive(Eq, Show, Debug)

/// Relational operators for attribute selectors.
pub enum AttributeOp {
  /// `[attr]` — attribute presence.
  Exists
  /// `[attr=value]` — exact equality.
  Equals
  /// `[attr~=value]` — whitespace-separated list contains value.
  Includes
  /// `[attr|=value]` — equals value or starts with value followed by `-`.
  DashMatch
  /// `[attr^=value]` — value is a prefix.
  Prefix
  /// `[attr$=value]` — value is a suffix.
  Suffix
  /// `[attr*=value]` — value is a substring.
  Substring
} derive(Eq, Show, Debug)

/// A single attribute selector, e.g. `[href^="/" i]`.
pub struct AttributeSelector {
  name : String
  op : AttributeOp
  value : String
  /// Case-insensitive modifier, e.g. `[attr=val i]`.
  icase : Bool
} derive(Eq, Show, Debug)

/// Argument for `:nth-child(an+b)` and friends.
pub struct Nth {
  a : Int
  b : Int
} derive(Eq, Show, Debug)

/// Pseudo-classes we support. Functional pseudo-classes carry their parsed
/// arguments.
pub enum PseudoClass {
  Root
  Empty
  FirstChild
  LastChild
  OnlyChild
  FirstOfType
  LastOfType
  OnlyOfType
  NthChild(Nth)
  NthLastChild(Nth)
  NthOfType(Nth)
  NthLastOfType(Nth)
  Enabled
  Disabled
  Checked
  Focus
  Hover
  /// `:lang(<language>)`
  Lang(String)
  /// `:not(<complex-selector-list>)`.
  Not(Array[ComplexSelector])
  /// `:is(<complex-selector-list>)`.
  Is(Array[ComplexSelector])
} derive(Eq, Show, Debug)

/// The smallest building block of a selector.
pub enum SimpleSelector {
  /// Type selector, e.g. `div`. Case-folded by the parser when appropriate.
  Type(String)
  /// Universal selector `*`.
  Universal
  /// Class selector `.foo`.
  Class(String)
  /// ID selector `#bar`.
  Id(String)
  /// Attribute selector.
  Attr(AttributeSelector)
  /// Pseudo-class.
  Pseudo(PseudoClass)
} derive(Eq, Show, Debug)

/// A compound selector is a sequence of simple selectors that must all match
/// the same element, e.g. `div#nav.active[href]`.
pub struct CompoundSelector {
  simples : Array[SimpleSelector]
} derive(Eq, Show, Debug)

/// A complex selector: a subject compound plus an ordered chain of ancestor
/// compounds linked by combinators.
pub struct ComplexSelector {
  /// The element being selected (rightmost simple selector).
  subject : CompoundSelector
  /// Ancestor chain, from the closest to the farthest.
  ancestors : Array[(Combinator, CompoundSelector)]
} derive(Eq, Show, Debug)

/// A parsed selector list: comma-separated complex selectors.
pub type SelectorList = Array[ComplexSelector]
