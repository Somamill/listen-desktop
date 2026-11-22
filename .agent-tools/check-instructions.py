"""Check repo-relative agent links and path-bearing validation commands."""
import re
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent


def missing_paths(text, root):
    links = re.findall(r'\]\(([^)\s]+)\)', text)
    paths = {link.split('#', 1)[0] for link in links
             if ':' not in link and not link.startswith(('#', '/'))}
    commands = re.findall(r'^\s*(?:\$ )?(?:python3|\.venv/bin/python)\s+([^\n]+)', text, re.M)
    for command in commands:
        words = command.split()
        if words[0] == '-m' and words[1:2] == ['pytest']:
            paths.update(word for word in words[2:] if not word.startswith('-'))
        elif words[0].endswith('.py'):
            paths.add(words[0])
    return sorted(path for path in paths
                  if not (root / path).resolve().is_relative_to(root) or not (root / path).exists())


if __name__ == '__main__':
    missing = missing_paths((ROOT / 'AGENTS.md').read_text(), ROOT)
    if missing:
        raise SystemExit('Missing instruction paths: ' + ', '.join(missing))
    print('Agent instruction links and validation paths exist.')
