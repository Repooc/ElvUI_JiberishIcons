"""A small Lua 5.1 parser for offline checks when no Lua runtime is installed.

It reports syntax errors, each function's peak count of active locals (the
compiler refuses more than 200), upvalues per function (Lua 5.1 refuses more
than 60) and every global read or write with its line. It does not run code.
"""
from dataclasses import dataclass, field
import re
import sys

MAX_LOCALS = 200
MAX_UPVALUES = 60
KEYWORDS = {
    'and', 'break', 'do', 'else', 'elseif', 'end', 'false', 'for', 'function', 'if', 'in',
    'local', 'nil', 'not', 'or', 'repeat', 'return', 'then', 'true', 'until', 'while',
}
SYMBOLS = ('...', '..', '==', '~=', '<=', '>=', '+', '-', '*', '/', '%', '^', '#', '<', '>', '=',
           '(', ')', '{', '}', '[', ']', ';', ':', ',', '.')
BINARY = {
    'or': (1, 1), 'and': (2, 2), '<': (3, 3), '>': (3, 3), '<=': (3, 3), '>=': (3, 3), '~=': (3, 3),
    '==': (3, 3), '..': (5, 4), '+': (6, 6), '-': (6, 6), '*': (7, 7), '/': (7, 7), '%': (7, 7),
    '^': (10, 9),
}
UNARY_PRIORITY = 8


class LuaSyntaxError(Exception):
    pass


@dataclass
class Token:
    kind: str  # name, number, string, keyword, symbol, eof
    value: str
    line: int


def tokenize(source):
    tokens, i, line, n = [], 0, 1, len(source)
    if source.startswith('#'):
        while i < n and source[i] != '\n':
            i += 1
    number = re.compile(r'0[xX][0-9a-fA-F]+|(\d+\.?\d*|\.\d+)([eE][+-]?\d+)?')
    while i < n:
        c = source[i]
        if c == '\n':
            line += 1; i += 1; continue
        if c in ' \t\r\f\v':
            i += 1; continue
        if source.startswith('--', i):
            i += 2
            m = re.match(r'\[(=*)\[', source[i:i + 260])
            if m:
                close = ']' + m.group(1) + ']'
                end = source.find(close, i)
                if end < 0:
                    raise LuaSyntaxError(f'line {line}: unfinished long comment')
                line += source.count('\n', i, end)
                i = end + len(close)
            else:
                while i < n and source[i] != '\n':
                    i += 1
            continue
        if c.isalpha() or c == '_':
            j = i
            while j < n and (source[j].isalnum() or source[j] == '_'):
                j += 1
            word = source[i:j]
            tokens.append(Token('keyword' if word in KEYWORDS else 'name', word, line))
            i = j; continue
        if c.isdigit() or (c == '.' and i + 1 < n and source[i + 1].isdigit()):
            m = number.match(source, i)
            tokens.append(Token('number', m.group(0), line))
            i = m.end(); continue
        if c in '"\'':
            j, start = i + 1, line
            while True:
                if j >= n or source[j] == '\n':
                    raise LuaSyntaxError(f'line {start}: unfinished string')
                if source[j] == '\\':
                    if j + 1 < n and source[j + 1] == '\n':
                        line += 1
                    j += 2; continue
                if source[j] == c:
                    break
                j += 1
            tokens.append(Token('string', source[i:j + 1], start))
            i = j + 1; continue
        m = re.match(r'\[(=*)\[', source[i:i + 260])
        if m:
            close = ']' + m.group(1) + ']'
            end = source.find(close, i)
            if end < 0:
                raise LuaSyntaxError(f'line {line}: unfinished long string')
            tokens.append(Token('string', source[i:end + len(close)], line))
            line += source.count('\n', i, end)
            i = end + len(close); continue
        for symbol in SYMBOLS:
            if source.startswith(symbol, i):
                tokens.append(Token('symbol', symbol, line))
                i += len(symbol)
                break
        else:
            raise LuaSyntaxError(f'line {line}: unexpected character {c!r}')
    tokens.append(Token('eof', '<eof>', line))
    return tokens


@dataclass
class Function:
    name: str
    line: int
    parent: 'Function' = None
    scopes: list = field(default_factory=list)
    active: int = 0
    peak: int = 0
    upvalues: set = field(default_factory=set)
    vararg: bool = False


@dataclass
class Report:
    functions: list = field(default_factory=list)  # (name, line, peak locals, upvalues)
    global_reads: dict = field(default_factory=dict)  # name -> first line
    global_writes: dict = field(default_factory=dict)


class Parser:
    def __init__(self, source):
        self.tokens = tokenize(source)
        self.pos = 0
        self.report = Report()
        self.fn = None
        self.pending_writes = []

    # Tokens --------------------------------------------------------------
    @property
    def tok(self):
        return self.tokens[self.pos]

    def peek(self, offset=1):
        return self.tokens[min(self.pos + offset, len(self.tokens) - 1)]

    def check(self, value):
        t = self.tok
        return t.kind in ('keyword', 'symbol') and t.value == value

    def accept(self, value):
        if self.check(value):
            self.pos += 1
            return True
        return False

    def expect(self, value, opener=None):
        if not self.accept(value):
            where = f' (to close line {opener})' if opener else ''
            raise LuaSyntaxError(f'line {self.tok.line}: {value!r} expected{where} near {self.tok.value!r}')

    def name(self):
        t = self.tok
        if t.kind != 'name':
            raise LuaSyntaxError(f'line {t.line}: name expected near {t.value!r}')
        self.pos += 1
        return t

    # Scopes --------------------------------------------------------------
    def open_function(self, name, line):
        self.fn = Function(name, line, self.fn)
        self.fn.scopes.append({})

    def close_function(self):
        fn = self.fn
        self.report.functions.append((fn.name, fn.line, fn.peak, len(fn.upvalues)))
        self.fn = fn.parent

    def open_scope(self):
        self.fn.scopes.append({})

    def close_scope(self):
        scope = self.fn.scopes.pop()
        self.fn.active -= len(scope)

    def declare(self, names):
        scope = self.fn.scopes[-1]
        for name in names:
            # A repeated local name in one scope is a new slot all the same.
            key = name
            while key in scope:
                key += "'"
            scope[key] = name
            self.fn.active += 1
        self.fn.peak = max(self.fn.peak, self.fn.active)

    def resolve(self, name, line, write=False):
        fn, depth = self.fn, 0
        chain = []
        while fn:
            for scope in reversed(fn.scopes):
                if name in scope.values():
                    for inner in chain:
                        inner.upvalues.add(name)
                    return 'local'
            chain.append(fn)
            fn = fn.parent
        target = self.report.global_writes if write else self.report.global_reads
        target.setdefault(name, line)
        return 'global'

    # Grammar -------------------------------------------------------------
    def chunk(self):
        self.open_function('main chunk', 1)
        self.fn.vararg = True
        self.block()
        if self.tok.kind != 'eof':
            raise LuaSyntaxError(f'line {self.tok.line}: <eof> expected near {self.tok.value!r}')
        self.close_function()
        return self.report

    def block_follow(self):
        t = self.tok
        return t.kind == 'eof' or (t.kind == 'keyword' and t.value in ('else', 'elseif', 'end', 'until'))

    def block(self):
        while not self.block_follow():
            if self.check('return'):
                self.pos += 1
                if not self.block_follow() and not self.check(';'):
                    self.exprlist()
                self.accept(';')
                if not self.block_follow():
                    raise LuaSyntaxError(f'line {self.tok.line}: return must be the last statement')
                return
            if self.check('break'):
                self.pos += 1
                self.accept(';')
                if not self.block_follow():
                    raise LuaSyntaxError(f'line {self.tok.line}: break must be the last statement')
                return
            self.statement()
            self.accept(';')

    def scoped_block(self):
        self.open_scope()
        self.block()
        self.close_scope()

    def statement(self):
        t = self.tok
        line = t.line
        if self.accept('if'):
            self.expr(); self.expect('then'); self.scoped_block()
            while self.accept('elseif'):
                self.expr(); self.expect('then'); self.scoped_block()
            if self.accept('else'):
                self.scoped_block()
            self.expect('end', line)
        elif self.accept('while'):
            self.expr(); self.expect('do'); self.scoped_block(); self.expect('end', line)
        elif self.accept('do'):
            self.scoped_block(); self.expect('end', line)
        elif self.accept('for'):
            first = self.name().value
            if self.accept('='):
                self.expr(); self.expect(','); self.expr()
                if self.accept(','):
                    self.expr()
                names = [first]
                hidden = 3
            else:
                names = [first]
                while self.accept(','):
                    names.append(self.name().value)
                self.expect('in')
                self.exprlist()
                hidden = 3
            self.expect('do')
            self.open_scope()
            self.declare(['(for)'] * hidden)
            self.open_scope()
            self.declare(names)
            self.block()
            self.close_scope()
            self.close_scope()
            self.expect('end', line)
        elif self.accept('repeat'):
            self.open_scope()
            self.block()
            self.expect('until', line)
            self.expr()  # the condition sees the loop's locals
            self.close_scope()
        elif self.accept('function'):
            target = self.name()
            label = target.value
            self.resolve(target.value, target.line, write=True)
            method = False
            while self.check('.') or self.check(':'):
                method = self.tok.value == ':'
                self.pos += 1
                label += ('.' if not method else ':') + self.name().value
                if method:
                    break
            self.body(label, line, method)
        elif self.accept('local'):
            if self.accept('function'):
                name = self.name().value
                self.declare([name])
                self.body(name, line, False)
            else:
                names = [self.name().value]
                while self.accept(','):
                    names.append(self.name().value)
                if self.accept('='):
                    self.exprlist()
                self.declare(names)
        else:
            self.expr_statement()

    def expr_statement(self):
        start = self.tok
        self.pending_writes = []
        kind = self.suffixed(assign_target=True)
        if self.check('=') or self.check(','):
            targets = [kind]
            while self.accept(','):
                targets.append(self.suffixed(assign_target=True))
            if any(k not in ('name', 'index') for k in targets):
                raise LuaSyntaxError(f'line {start.line}: cannot assign to this expression')
            writes, self.pending_writes = self.pending_writes, []
            self.expect('=')
            self.exprlist()
            for name, line in writes:
                self.resolve(name, line, write=True)
        else:
            self.pending_writes = []
            if kind != 'call':
                raise LuaSyntaxError(f'line {start.line}: syntax error near {self.tok.value!r}')

    def body(self, label, line, method):
        self.open_function(label, line)
        if method:
            self.declare(['self'])
        self.expect('(')
        names = []
        if not self.check(')'):
            while True:
                if self.accept('...'):
                    self.fn.vararg = True
                    break
                names.append(self.name().value)
                if not self.accept(','):
                    break
        self.expect(')')
        self.declare(names)
        self.block()
        self.expect('end', line)
        self.close_function()

    def exprlist(self):
        self.expr()
        while self.accept(','):
            self.expr()

    def primary(self, assign_target=False):
        t = self.tok
        if t.kind == 'name':
            self.pos += 1
            if assign_target:
                # Decide read or write after seeing what follows.
                if self.check('=') or self.check(','):
                    self.pending_writes.append((t.value, t.line))
                    return 'name'
            self.resolve(t.value, t.line)
            return 'name'
        if self.accept('('):
            self.expr()
            self.expect(')', t.line)
            return 'paren'
        raise LuaSyntaxError(f'line {t.line}: unexpected symbol near {t.value!r}')

    def suffixed(self, assign_target=False):
        kind = self.primary(assign_target)
        while True:
            if self.check('.'):
                self.pos += 1; self.name(); kind = 'index'
            elif self.check('['):
                line = self.tok.line
                self.pos += 1; self.expr(); self.expect(']', line); kind = 'index'
            elif self.check(':'):
                self.pos += 1; self.name(); self.call_args(); kind = 'call'
            elif self.check('(') or self.check('{') or self.tok.kind == 'string':
                if self.check('(') and self.tok.line != self.tokens[self.pos - 1].line:
                    raise LuaSyntaxError(f'line {self.tok.line}: ambiguous syntax (function call x new statement)')
                self.call_args(); kind = 'call'
            else:
                return kind

    def call_args(self):
        t = self.tok
        if t.kind == 'string':
            self.pos += 1
        elif self.check('{'):
            self.table()
        else:
            self.expect('(')
            if not self.check(')'):
                self.exprlist()
            self.expect(')', t.line)

    def table(self):
        line = self.tok.line
        self.expect('{')
        while not self.check('}'):
            if self.check('['):
                self.pos += 1; self.expr(); self.expect(']'); self.expect('='); self.expr()
            elif self.tok.kind == 'name' and self.peek().kind == 'symbol' and self.peek().value == '=':
                self.pos += 2; self.expr()
            else:
                self.expr()
            if not (self.accept(',') or self.accept(';')):
                break
        self.expect('}', line)

    def simple(self):
        t = self.tok
        if t.kind in ('number', 'string'):
            self.pos += 1
        elif t.kind == 'keyword' and t.value in ('nil', 'true', 'false'):
            self.pos += 1
        elif self.check('...'):
            if not self.fn.vararg:
                raise LuaSyntaxError(f"line {t.line}: cannot use '...' outside a vararg function")
            self.pos += 1
        elif self.check('{'):
            self.table()
        elif self.accept('function'):
            self.body('anonymous', t.line, False)
        else:
            self.suffixed()

    def expr(self, limit=0):
        t = self.tok
        if (t.kind == 'keyword' and t.value == 'not') or (t.kind == 'symbol' and t.value in ('-', '#')):
            self.pos += 1
            self.expr(UNARY_PRIORITY)
        else:
            self.simple()
        while True:
            t = self.tok
            op = t.value if t.kind in ('keyword', 'symbol') else None
            if op not in BINARY or BINARY[op][0] <= limit:
                return
            self.pos += 1
            self.expr(BINARY[op][1])


def analyze(source):
    """Parse one file. Returns a Report, or raises LuaSyntaxError."""
    if source.startswith('﻿'):
        source = source[1:]
    return Parser(source).chunk()


def problems(source):
    """Syntax and compiler-limit problems, as strings."""
    try:
        report = analyze(source)
    except LuaSyntaxError as error:
        return [str(error)]
    found = []
    for name, line, peak, upvalues in report.functions:
        if peak >= MAX_LOCALS:
            found.append(f'line {line}: {name} has {peak} active locals (limit {MAX_LOCALS})')
        if upvalues > MAX_UPVALUES:
            found.append(f'line {line}: {name} has {upvalues} upvalues (limit {MAX_UPVALUES})')
    return found


def main(paths):
    status = 0
    for path in paths:
        with open(path, encoding='utf-8-sig') as handle:
            source = handle.read()
        issues = problems(source)
        if issues:
            status = 1
            for issue in issues:
                print(f'{path}: {issue}')
        else:
            report = analyze(source)
            main_peak = next(peak for name, _, peak, _ in report.functions if name == 'main chunk')
            print(f'OK {path}: main chunk {main_peak} locals; globals read {len(report.global_reads)}, '
                  f'written {len(report.global_writes)}')
    return status


if __name__ == '__main__':
    sys.exit(main(sys.argv[1:]))
