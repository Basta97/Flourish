#!/usr/bin/env python3
"""Merge a batch of strings into lib/l10n/app_en.arb and app_ar.arb.

Usage: python3 tool/l10n_add.py batch.json

batch.json maps a message key to [english, arabic] or
[english, arabic, {"placeholder": "type"}]. Placeholders are found in the
English text ({name}); plural/select placeholders default to int/String,
others to String unless typed in the third element.
"""
import json
import re
import sys
from collections import OrderedDict

EN = 'lib/l10n/app_en.arb'
AR = 'lib/l10n/app_ar.arb'


def load(path, locale):
    try:
        with open(path, encoding='utf-8') as f:
            return json.load(f, object_pairs_hook=OrderedDict)
    except FileNotFoundError:
        return OrderedDict([('@@locale', locale)])


def placeholders(text, types):
    found = OrderedDict()
    for m in re.finditer(r'(?<![\w=])\{(\w+)(?:,\s*(plural|select))?', text):
        name, kind = m.group(1), m.group(2)
        if name in found and not kind:
            continue
        if kind == 'plural':
            found[name] = 'int'
        elif kind == 'select':
            found[name] = 'String'
        elif name not in found:
            found[name] = 'String'
    # Words inside plural branches like {=1{...}} are not placeholders.
    for name in list(found):
        if not re.search(r'\{' + name + r'(\}|,)', text):
            del found[name]
    found.update(types)
    return found


def main():
    batch = json.load(open(sys.argv[1], encoding='utf-8'),
                      object_pairs_hook=OrderedDict)
    en, ar = load(EN, 'en'), load(AR, 'ar')
    for key, value in batch.items():
        english, arabic = value[0], value[1]
        types = value[2] if len(value) > 2 else {}
        if key in en and en[key] != english:
            print(f'warning: {key} changed: {en[key]!r} -> {english!r}')
        en[key] = english
        ar[key] = arabic
        ph = placeholders(english, types)
        if ph:
            en['@' + key] = {
                'placeholders': {n: {'type': t} for n, t in ph.items()}
            }
        else:
            en.pop('@' + key, None)
    for path, data in ((EN, en), (AR, ar)):
        with open(path, 'w', encoding='utf-8') as f:
            json.dump(data, f, ensure_ascii=False, indent=2)
            f.write('\n')
    print(f'{len(batch)} strings merged; {sum(1 for k in en if not k.startswith("@"))} total')


if __name__ == '__main__':
    main()
