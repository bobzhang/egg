///|
pub suberror ParseError {
  ParseError(String)
} derive(Debug)

///|
priv enum Token {
  Open
  Close
  Atom(String)
}

///|
fn tokenize(text : String) -> Array[Token] raise ParseError {
  let chars = text.to_array()
  let tokens = []
  let mut i = 0
  while i < chars.length() {
    let c = chars[i]
    if c.is_whitespace() {
      i += 1
      continue
    }
    if c == '(' {
      tokens.push(Open)
      i += 1
      continue
    }
    if c == ')' {
      tokens.push(Close)
      i += 1
      continue
    }
    let atom = StringBuilder()
    if c == '"' {
      i += 1
      let mut closed = false
      while i < chars.length() {
        let c = chars[i]
        i += 1
        if c == '"' {
          closed = true
          break
        }
        if c == '\\' {
          guard i < chars.length() else {
            raise ParseError("unfinished escape")
          }
          match chars[i] {
            'n' => atom.write_char('\n')
            'r' => atom.write_char('\r')
            't' => atom.write_char('\t')
            '"' => atom.write_char('"')
            '\\' => atom.write_char('\\')
            _ => raise ParseError("unsupported quoted-atom escape")
          }
          i += 1
        } else {
          atom.write_char(c)
        }
      }
      guard closed else { raise ParseError("unterminated quoted atom") }
      if i < chars.length() &&
        !chars[i].is_whitespace() &&
        chars[i] != ')' &&
        chars[i] != '(' {
        raise ParseError("quoted atom requires a delimiter")
      }
    } else {
      while i < chars.length() &&
            !chars[i].is_whitespace() &&
            chars[i] != '(' &&
            chars[i] != ')' {
        guard chars[i] != '"' else {
          raise ParseError("quote inside unquoted atom")
        }
        atom.write_char(chars[i])
        i += 1
      }
    }
    tokens.push(Atom(atom.to_string()))
  }
  tokens
}

///|
/// Parses one S-expression, using an iterative stack. Quoted atoms support
/// quote, backslash, newline, carriage return, and tab escapes.
pub fn Expr::parse(text : String) -> Expr[String] raise ParseError {
  let tokens = tokenize(text)
  let expr = Expr()
  let stack : Array[(String, Array[Int32])] = []
  let mut root : Int32? = None
  let mut i = 0
  while i < tokens.length() {
    if root is Some(_) {
      raise ParseError("more than one expression")
    }
    match tokens[i] {
      Open => {
        i += 1
        guard i < tokens.length() else { raise ParseError("missing operator") }
        guard tokens[i] is Atom(op) else {
          raise ParseError("expected operator atom")
        }
        stack.push((op, []))
      }
      Atom(op) => {
        let id = expr.add(Node(op))
        if stack.is_empty() {
          root = Some(id)
        } else {
          stack[stack.length() - 1].1.push(id)
        }
      }
      Close => {
        guard stack.pop() is Some((op, children)) else {
          raise ParseError("unmatched closing parenthesis")
        }
        let id = expr.add(Node(op, children~))
        if stack.is_empty() {
          root = Some(id)
        } else {
          stack[stack.length() - 1].1.push(id)
        }
      }
    }
    i += 1
  }
  guard stack.is_empty() else { raise ParseError("unclosed expression") }
  guard root is Some(_) else { raise ParseError("empty input") }
  expr
}

///|
fn quote_atom(atom : String) -> String {
  if !atom.is_empty() &&
    atom
    .to_array()
    .all(c => {
      !c.is_whitespace() && c != '(' && c != ')' && c != '"' && c != '\\'
    }) {
    return atom
  }
  let out = StringBuilder()
  out.write_char('"')
  for c in atom {
    match c {
      '"' => out.write_string("\\\"")
      '\\' => out.write_string("\\\\")
      '\n' => out.write_string("\\n")
      '\r' => out.write_string("\\r")
      '\t' => out.write_string("\\t")
      _ => out.write_char(c)
    }
  }
  out.write_char('"')
  out.to_string()
}

///|
/// Prints the expression rooted at its last node. Shared DAG nodes are expanded.
pub fn Expr::to_string(self : Expr[String]) -> String {
  let rendered : Array[String] = []
  for node in self.nodes {
    let op = quote_atom(node.op)
    rendered.push(
      if node.children.is_empty() {
        op
      } else {
        "(" + op + " " + node.children.map(id => rendered[id]).join(" ") + ")"
      },
    )
  }
  rendered[self.root()]
}

///|
pub extend ParseError with Debug::{to_repr}
