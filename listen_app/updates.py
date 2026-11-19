"""Stable desktop release checks; never downloads or executes an update."""
import argparse
import json
import threading
import time
from packaging.version import Version, InvalidVersion
import requests
from . import __version__, settings

REPOSITORY = 'Somamill/listen-desktop'
LOCK = threading.Lock()

def check(force=False):
    path = settings.data_dir() / 'update-check.json'
    with LOCK:
        saved = settings.read_json(path, {})
        if not force and isinstance(saved, dict) and 0 <= time.time()-saved.get('checked_at', 0) < 86400:
            return saved
        response = requests.get('https://api.github.com/repos/'+REPOSITORY+'/releases', params={'per_page': 20},
            headers={'Accept': 'application/vnd.github+json', 'User-Agent': 'listen-desktop/'+__version__}, timeout=8, allow_redirects=False)
        response.raise_for_status()
        if len(response.content) > 2_000_000:
            raise ValueError('Release response is too large.')
        rows = response.json()
        if not isinstance(rows, list):
            raise ValueError('Invalid release response.')
        choices = []
        for release in rows:
            if not isinstance(release, dict) or release.get('draft') or release.get('prerelease'):
                continue
            url = release.get('html_url', '')
            if not isinstance(url, str) or not url.startswith('https://github.com/'+REPOSITORY+'/releases/tag/'):
                continue
            try:
                version = Version(release.get('tag_name', '').removeprefix('v'))
            except (InvalidVersion, TypeError, AttributeError):
                continue
            if not version.is_prerelease:
                choices.append((version, url))
        result = {'current': __version__, 'available': False, 'checked_at': time.time(), 'message': 'No public release is available yet.'}
        if choices:
            version, url = max(choices)
            result.update(latest=str(version), available=version > Version(__version__), url=url,
                message='A newer release is available.' if version > Version(__version__) else 'You are using the latest published version.')
        settings.atomic_json(path, result)
        return result

def background():
    try:
        check()
    except (requests.RequestException, ValueError, OSError):
        pass  # The manual checker reports failures; startup remains available offline.

def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--check', action='store_true', help='Check the official desktop release without installing it')
    parser.parse_args()
    try:
        print(json.dumps(check(force=True), ensure_ascii=False))
    except (requests.RequestException, ValueError, OSError) as error:
        parser.exit(2, 'Could not check releases: '+str(error)+'\n')

if __name__ == '__main__':
    main()
