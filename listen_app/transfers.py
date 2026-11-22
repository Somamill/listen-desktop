"""Durable, local-only cleanup after a client finishes moving every file."""
import json
import logging
import threading
import time
from pathlib import Path

from . import settings

LOCK = threading.Lock()
FINISH_LOCK = threading.Lock()
WAKE = threading.Event()
ACKNOWLEDGED = set()
DIAGNOSTIC = {'state': 'idle', 'pending': 0, 'retry_at': None}
MESSAGES = {
    'client_unavailable': 'Check that the configured local client is running and its connection settings are correct.',
    'cleanup_failed': 'Torrent removal could not be confirmed. Check the local client before retrying.',
    'journal_error': 'Check the transfer journal and permissions on the application data directory.',
    'configuration_changed': 'Reconnect the local client that started the transfer.',
    'missing': 'The client did not report a pending torrent. Check its status in the client.',
    'verification_pending': 'Check that every moved file is in the library and absent from downloads.',
    'client_error': 'Resolve the reported torrent error in the local client.',
}


def journal():
    return settings.data_dir() / 'library-transfers.json'


def pending():
    # A malformed journal must not be mistaken for an empty queue or overwritten.
    try:
        with journal().open() as file:
            jobs = json.load(file)
    except FileNotFoundError:
        return {}
    if not isinstance(jobs, dict):
        raise ValueError('Invalid transfer journal.')
    return jobs


def manifest(source):
    source = Path(source)
    files = [source] if source.is_file() else list(source.rglob('*'))
    if source.is_symlink() or any(path.is_symlink() for path in files):
        raise ValueError('Symbolic links cannot be transferred automatically.')
    result = {('.' if path == source else str(path.relative_to(source))): path.stat().st_size
              for path in files if path.is_file() and path.name != '.DS_Store'}
    if not result:
        raise ValueError('No completed files found.')
    return result


def record(torrent_id, cfg, source, target):
    files = manifest(source)
    with LOCK:
        jobs = pending()
        key = str(torrent_id)
        if key in jobs:
            raise ValueError('This transfer is already pending. The torrent is removed after verification.')
        jobs[key] = {'client': cfg['client']['type'], 'url': cfg['client']['url'],
                     'source': str(source), 'target': str(target), 'folder': cfg['completed_folder'],
                     'downloads': cfg['downloads_folder'], 'files': files}
        settings.atomic_json(journal(), jobs)
    WAKE.set()


def forget(key):
    with LOCK:
        jobs = pending()
        jobs.pop(str(key), None)
        settings.atomic_json(journal(), jobs)


def verified(job):
    source, target = Path(job['source']), Path(job['target'])
    files = job['files']
    if not source.is_absolute() or not target.is_absolute() or not files or target.parent != Path(job['folder']) or target.name != source.name:
        return False
    source = source.parent.resolve() / source.name
    target = target.parent.resolve() / target.name
    for relative, size in files.items():
        rel = Path(relative)
        if rel.is_absolute() or '..' in rel.parts:
            return False
        moved, original = target / rel, source / rel
        if moved.resolve() != moved.absolute() or original.resolve() != original.absolute():
            return False
        if not moved.is_file() or moved.stat().st_size != size:
            return False
        try:
            original.lstat()
        except FileNotFoundError:
            continue
        return False
    return True


def remove_empty_source(job):
    source = Path(job['source'])
    if source.is_symlink():
        return
    if source.is_dir():
        for path in sorted(source.rglob('*'), key=lambda path: len(path.parts), reverse=True):
            try:
                if path.is_symlink():
                    continue
                if path.is_file() and path.name == '.DS_Store':
                    path.unlink()
                if path.is_dir():
                    path.rmdir()
            except OSError:
                pass
        try:
            source.rmdir()
        except OSError:
            pass
    downloads = Path(job['downloads']).resolve()
    parent = source.parent
    while downloads in parent.resolve().parents:
        try:
            parent.rmdir()
        except OSError:
            break
        parent = parent.parent


def valid_job(job):
    return (isinstance(job, dict)
            and all(isinstance(job.get(field), str) for field in
                    ('client', 'url', 'source', 'target', 'folder', 'downloads'))
            and isinstance(job.get('files'), dict) and bool(job['files'])
            and all(type(size) is int and size >= 0 for size in job['files'].values()))


def finish_pending(cfg=None, stop=None):
    from . import clients
    with FINISH_LOCK:
        jobs = pending()
        if not jobs or (stop and stop.is_set()):
            return 'idle', len(jobs)
        cfg = cfg or settings.load()
        valid = {key: job for key, job in jobs.items() if valid_job(job)}
        matching = {key: job for key, job in valid.items()
                    if job['client'] == cfg['client']['type'] and job['url'] == cfg['client']['url']}
        issues = set()
        if len(valid) != len(jobs):
            issues.add('journal_error')
        if not clients.is_local(cfg) or not matching:
            return ('journal_error' if issues else 'configuration_changed'), len(jobs)
        try:
            rows = {str(row['id']): row for row in clients.torrents(cfg)}
        except Exception:
            return 'client_unavailable', len(jobs)

        remaining = len(jobs)
        if len(matching) != len(valid):
            issues.add('configuration_changed')
        for key, job in matching.items():
            if stop and stop.is_set():
                break
            receipt = (journal(), key)
            if receipt not in ACKNOWLEDGED:
                row = rows.get(key)
                if row is None:
                    issues.add('missing')
                    continue
                state = row['state'].casefold()
                if any(term in state for term in ('error', 'missing')):
                    issues.add('client_error')
                    continue
                if row['progress'] < 1 or not clients.in_library(row['save_path'], job['folder']) or any(
                    term in state for term in ('moving', 'checking')
                ):
                    issues.add('moving')
                    continue
                try:
                    ready = verified(job)
                except (OSError, RuntimeError, ValueError):
                    ready = False
                if not ready:
                    issues.add('verification_pending')
                    continue
                if stop and stop.is_set():
                    break
                try:
                    client = clients._connect(cfg)
                    if stop and stop.is_set():
                        break
                    if not verified(job):
                        issues.add('verification_pending')
                        continue
                    if job['client'] == 'qbittorrent':
                        client.torrents_delete(torrent_hashes=key, delete_files=False)
                    elif job['client'] == 'transmission':
                        client.remove_torrent(ids=[int(key)], delete_data=False)
                    else:
                        result = client.execute_call({'method': 'core.remove_torrent', 'params': [key, False]}, timeout=8)
                        if result.result is not True:
                            issues.add('cleanup_failed')
                            continue
                except Exception:
                    issues.add('cleanup_failed')
                    continue
                ACKNOWLEDGED.add(receipt)
            forget(key)
            ACKNOWLEDGED.discard(receipt)
            remaining -= 1
            try:
                remove_empty_source(job)
            except OSError:
                pass
        for state in ('journal_error', 'cleanup_failed', 'client_error', 'configuration_changed', 'missing',
                      'verification_pending', 'moving'):
            if state in issues:
                return state, remaining
        return 'idle', remaining


def monitor(stop, *, wait=None, now=time.time):
    global DIAGNOSTIC
    wait = wait or WAKE.wait
    delay = None
    previous = None
    while not stop.is_set():
        WAKE.clear()
        try:
            state, count = finish_pending(stop=stop)
        except Exception:
            state, count = 'journal_error', None
        if stop.is_set():
            break
        if state == 'idle':
            delay = None
        else:
            minimum, maximum = (2, 15) if state == 'moving' else (5, 120)
            delay = min(maximum, delay * 2) if state == previous and delay else minimum
        message = MESSAGES.get(state)
        snapshot = {'state': state, 'pending': count, 'retry_at': now() + delay if delay else None}
        if message:
            snapshot['action'] = message
            if previous != state:
                logging.getLogger(__name__).warning('Transfer monitor (%s): %s', state, message)
        DIAGNOSTIC = snapshot
        previous = state
        wait(delay)
    DIAGNOSTIC = {'state': 'stopped', 'pending': None, 'retry_at': None}
