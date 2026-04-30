import json, re, os

ar = json.load(open('lib/core/localization/l10n/app_ar.arb'))
en = json.load(open('lib/core/localization/l10n/app_en.arb'))
valid = {k for k in ar if not k.startswith('@') and k != '@@locale'}

issues = []

for root, dirs, files in os.walk('lib'):
    for fn in files:
        if not fn.endswith('.dart'):
            continue
        path = os.path.join(root, fn)
        if '/generated/' in path:
            continue
        with open(path) as f:
            content = f.read()
            lines = content.split('\n')
        has_import = 'app_localizations' in content
        uses_loc = 'AppLocalizations.of(context)' in content
        if uses_loc and not has_import:
            issues.append(('MISSING_IMPORT', path, 0, 'uses AppLocalizations but no import'))
        for i, line in enumerate(lines, 1):
            s = line.strip()
            if s.startswith('//'):
                continue
            # Hardcoded Arabic in quotes
            if re.search(r"['\"].*[\u0600-\u06FF].*['\"]", line):
                # Skip Arabic comma join separator
                if "join('\u060c')" in line or 'join("\u060c")' in line:
                    continue
                issues.append(('HARDCODED_AR', path, i, s[:120]))
            # Invalid localization key
            for m in re.finditer(r'AppLocalizations\.of\(context\)!\.(\w+)', line):
                if m.group(1) not in valid:
                    issues.append(('INVALID_KEY', path, i, m.group(1)))

print(f'Total issues: {len(issues)}')
for t, p, i, d in sorted(issues):
    print(f'  [{t}] {p}:{i} | {d}')

# Also check: files using AppLocalizations but missing import
print(f'\n--- Missing imports: {sum(1 for t,_,_,_ in issues if t=="MISSING_IMPORT")} ---')
print(f'--- Hardcoded AR: {sum(1 for t,_,_,_ in issues if t=="HARDCODED_AR")} ---')
print(f'--- Invalid keys: {sum(1 for t,_,_,_ in issues if t=="INVALID_KEY")} ---')
