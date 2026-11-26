#!/usr/bin/env python3
"""bdf2v.py - Convierte un .bdf de Quartus (bloques + pines + cables) en el
modulo Verilog equivalente, para simularlo con Icarus.

    python3 tools/bdf2v.py <archivo.bdf> <nombre_modulo> <salida.v>

Conecta por geometria (extremos de cables que se tocan) y por nombre de red
(etiquetas iguales = misma red; admite rebanadas como m_result[1..0]).
Reporta: entradas sin conectar, redes con mas de un driver o sin driver,
salidas sin driver, anchos que no coinciden y cables con dos nombres.
Sale con codigo 1 si encontro errores."""
import re, sys

def tokenize(s):
    s = re.sub(r"/\*.*?\*/", "", s, flags=re.S)
    return re.findall(r'\(|\)|"(?:[^"\\]|\\.)*"|[^\s()]+', s)

def parse(toks):
    stack = [[]]
    for t in toks:
        if t == "(": stack.append([])
        elif t == ")":
            x = stack.pop(); stack[-1].append(x)
        else: stack[-1].append(t.strip('"') if t.startswith('"') else t)
    return stack[0]

def find(node, key):
    return [c for c in node if isinstance(c, list) and c and c[0] == key]

def pt(n): return (int(n[1]), int(n[2]))

def width(name):
    m = re.search(r"\[(\d+)\.\.(\d+)\]$", name)
    return (int(m.group(1)) - int(m.group(2)) + 1) if m else 1

def rng(name):
    """(hi, lo) del rango de una etiqueta: x[3..0] -> (3,0), x[5] -> (5,5), x -> None"""
    m = re.search(r"\[(\d+)(?:\.\.(\d+))?\]$", name)
    if not m: return None
    return int(m.group(1)), int(m.group(2) if m.group(2) is not None else m.group(1))

def base(name): return re.sub(r"\[.*\]$", "", name)

tree = parse(tokenize(open(sys.argv[1]).read()))
top = sys.argv[2]

# Union-find sobre puntos
par = {}
def f(a):
    par.setdefault(a, a)
    while par[a] != a:
        par[a] = par[par[a]]; a = par[a]
    return a
def u(a, b): par[f(a)] = f(b)

segs, labels = [], []
for c in find(tree, "connector"):
    p = [pt(x) for x in find(c, "pt")]
    segs.append(p); u(p[0], p[1])
    t = find(c, "text")
    if t: labels.append((p[0], t[0][1]))

def on_seg(q, s):
    (x1, y1), (x2, y2) = s
    if x1 == x2 == q[0] and min(y1, y2) <= q[1] <= max(y1, y2): return True
    if y1 == y2 == q[1] and min(x1, x2) <= q[0] <= max(x1, x2): return True
    return False

# extremos que tocan otro segmento tambien conectan (conservador)
for s in segs:
    for e in s:
        for s2 in segs:
            if s2 is not s and on_seg(e, s2): u(e, s2[0])

ports = []   # (inst, mod, port, dir, point)
pins = []
for p in find(tree, "pin"):
    d = p[1][0]
    r = [int(v) for v in find(p, "rect")[0][1:]]
    name = find(p, "text")[1][1]
    q = pt(find(p, "pt")[0]); q = (r[0] + q[0], r[1] + q[1])
    pins.append((name, d, q))
for s in find(tree, "symbol"):
    r = [int(v) for v in find(s, "rect")[0][1:]]
    texts = find(s, "text")
    mod, inst = texts[0][1], texts[1][1]
    for po in find(s, "port"):
        q = pt(find(po, "pt")[0])
        d = po[2][0]
        ports.append((inst, mod, find(po, "text")[0][1], d, (r[0] + q[0], r[1] + q[1])))

all_pts = [q for *_, q in ports] + [q for *_, q in pins]
for q in all_pts:
    for s in segs:
        if on_seg(q, s): u(q, s[0])

names = {}
for q, l in labels: names.setdefault(f(q), set()).add(l)
for n, d, q in pins: names.setdefault(f(q), set()).add(n)

errors = 0
for k, v in names.items():
    if len({base(x) for x in v}) > 1:
        print("ERROR red con varios nombres:", v); errors += 1
# redes por nombre (mismo nombre = misma red aunque no se toquen)
def netlabel(q):
    v = names.get(f(q))
    return sorted(v)[0] if v else None

drivers = {}
inst_conn = {}
netw = {}
for n, d, q in pins: netw[base(n)] = width(n)
for q, l in labels:
    r = rng(l)
    netw[base(l)] = max(netw.get(base(l), 1), (r[0] + 1) if r else 1)
for inst, mod, port, d, q in ports:
    lab = netlabel(q)
    n = base(lab) if lab else None
    inst_conn.setdefault((inst, mod), []).append((base(port), d, lab, width(port)))
    if n and d == "output": drivers.setdefault(n, []).append(inst + "." + port)
    if lab:
        r = rng(lab); lw = (r[0] - r[1] + 1) if r else 1
        if lw != width(port):
            print(f"ERROR ancho: {inst}.{port} ({width(port)}) <- {lab}"); errors += 1
for n, d, q in pins:
    if d == "input": drivers.setdefault(base(n), []).append("pin " + n)

for (inst, mod), cl in inst_conn.items():
    for p, d, n, wd in cl:
        if d == "input" and n is None:
            print(f"ERROR entrada sin conectar: {inst}.{p}"); errors += 1
allnets = {}
for (inst, mod), cl in inst_conn.items():
    for p, d, n, wd in cl:
        if n: allnets[base(n)] = netw[base(n)]
for n in allnets:
    dv = drivers.get(n, [])
    if len(dv) != 1:
        print(f"ERROR red {n}: drivers {dv}"); errors += 1

for n, d, q in pins:
    if d == "output" and base(n) not in drivers:
        print(f"ERROR salida {n} sin driver"); errors += 1

# Verilog
pin_names = {base(n): (d, width(n)) for n, d, q in pins}
v = [f"module {top} ("]
v.append(",\n".join(f"    {'input ' if d=='input' else 'output'} wire [{wd-1}:0] {n}" for n, (d, wd) in pin_names.items()))
v.append(");")
for n, wd in allnets.items():
    if n not in pin_names: v.append(f"    wire [{wd-1}:0] {n};")
for (inst, mod), cl in inst_conn.items():
    def expr(lab):
        if not lab: return ""
        b, r = base(lab), rng(lab)
        if r is None or (r[1] == 0 and r[0] + 1 == netw[b]): return b
        return f"{b}[{r[0]}]" if r[0] == r[1] else f"{b}[{r[0]}:{r[1]}]"
    cs = ",\n".join(f"        .{p}({expr(n)})" for p, d, n, wd in cl)
    v.append(f"    {mod} {inst} (\n{cs}\n    );")
v.append("endmodule")
open(sys.argv[3], "w").write("\n".join(v) + "\n")
print(f"{len(ports)} puertos, {len(pins)} pines, {len(allnets)} redes, errores: {errors}")
sys.exit(1 if errors else 0)
