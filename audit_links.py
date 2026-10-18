#!/usr/bin/env python3
"""Find Class::Method references in sources where no matching definition exists anywhere."""
import os, re

ROOTS = ["source/cpp"]

def read(p):
    try:
        with open(p, 'r', errors='ignore') as f:
            return f.read()
    except OSError:
        return ''

files = []
for root in ROOTS:
    for dp, _, fns in os.walk(root):
        for f in fns:
            if f.endswith(('.h', '.hpp', '.mm', '.cpp', '.c')):
                files.append(os.path.join(dp, f))
texts = {p: read(p) for p in files}
allsrc = "\n".join(texts.values())

# definitions: pairs "A::B(" that are followed later by "{" (crude but effective) OR "A::B(" appearing at line start with {
defined_pairs = set()
for m in re.finditer(r'([A-Za-z_][A-Za-z_0-9]*)::([A-Za-z_][A-Za-z_0-9]*)\s*\([^;{]*\)\s*(?:const\s*)?\{', allsrc):
    defined_pairs.add((m.group(1), m.group(2)))
# also inline-defined inside class bodies count: any "B(" in a header after "class A" — skip for now

defined_methods = {b for a, b in defined_pairs}

refs = {}
for m in re.finditer(r'([A-Za-z_][A-Za-z_0-9]*)::([A-Za-z_][A-Za-z_0-9]*)\s*\(', allsrc):
    refs.setdefault((m.group(1), m.group(2)), 0)
    refs[(m.group(1), m.group(2))] += 1

missing = []
for (a, b), cnt in sorted(refs.items()):
    if (a, b) in defined_pairs:
        continue
    if b in defined_methods:
        continue  # defined under another namespace scope
    # skip enum/struct member access patterns like std::string etc
    if a in ('std', 'ios', 'UI', 'AIFeatures', 'AdvancedBypass', 'Memory', 'Hooks', 'Security', 'Logging', 'Performance', 'RobloxExecutor', 'LocalModels', 'VulnerabilityDetection', 'iOS_'):
        missing.append((a, b, cnt))
        continue
    missing.append((a, b, cnt))

seen = set()
for a, b, cnt in missing:
    key = b
    if key in seen:
        continue
    seen.add(key)
    print(f"{a}::{b}  (refs={cnt})  NO-DEF")
