#!/usr/bin/env python3
"""Per-class audit: declared methods vs defined (Class::method) vs referenced (link-breaking)."""
import os, re

ROOT = "source/cpp"

def read(p):
    try:
        with open(p, 'r', errors='ignore') as f:
            return f.read()
    except OSError:
        return ''

files = []
for dp, _, fns in os.walk(ROOT):
    for f in fns:
        if f.endswith(('.h', '.hpp', '.mm', '.cpp', '.c')):
            files.append(os.path.join(dp, f))
texts = {p: read(p) for p in files}
allsrc = "\n".join(texts.values())

# Collect all defined symbols "Name::method(" across sources, and all referenced "->method(" / ".method("
defined_syms = set(re.findall(r'([A-Za-z_][A-Za-z_0-9]*)::([A-Za-z_][A-Za-z_0-9]*)\s*\(', allsrc))
defined_names = {m for _, m in defined_syms}
referenced = set(re.findall(r'(?:->|\.)([A-Za-z_][A-Za-z_0-9]*)\s*\(', allsrc))

decl_re = re.compile(r'^\s*(?:static\s+)?(?:virtual\s+)?[A-Za-z_][A-Za-z_0-9:<>,\s\*&]*?\s+([A-Za-z_][A-Za-z_0-9]*)\s*\([^;{]*\)\s*(?:const\s*)?;', re.M)
class_re = re.compile(r'(?:class|struct)\s+([A-Za-z_][A-Za-z_0-9]*)\b')

for h, text in texts.items():
    if not h.endswith(('.h', '.hpp')):
        continue
    decls = set(decl_re.findall(text))
    missing_ref = sorted(m for m in decls if m not in defined_names and m in referenced and len(m) > 2)
    missing_unref = sorted(m for m in decls if m not in defined_names and m not in referenced and len(m) > 2)
    if missing_ref or missing_unref:
        print(f"== {h}")
        if missing_ref:
            print("   LINK-BREAKING:", ", ".join(missing_ref))
        if missing_unref:
            print("   dead-decls:", ", ".join(missing_unref))
