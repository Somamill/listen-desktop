import copy
import runpy
import threading
import time
from concurrent.futures import ThreadPoolExecutor
from pathlib import Path
from unittest.mock import Mock

import pytest

from listen_app import clients, settings, transfers


@pytest.fixture
def transfer(tmp_path, monkeypatch):
    monkeypatch.setenv('LISTEN_DATA_DIR', str(tmp_path))
    monkeypatch.setattr(transfers, 'WAKE', threading.Event())
    monkeypatch.setattr(transfers, 'ACKNOWLEDGED', set())
    cfg = copy.deepcopy(settings.DEFAULTS)
    cfg['client']['type'] = 'qbittorrent'
    source = tmp_path / 'downloads' / 'Book'
    target = tmp_path / 'library' / 'Book'
    source.mkdir(parents=True)
    target.parent.mkdir()
    cfg.update(downloads_folder=str(source.parent), completed_folder=str(target.parent))
    (source / 'chapter.m4b').write_bytes(b'recording')
    (source / 'cover.jpg').write_bytes(b'cover')
    monkeypatch.setattr(settings, 'load', lambda: cfg)
    rows = Mock(return_value=[])
    rpc = Mock()
    monkeypatch.setattr(clients, 'torrents', rows)
    monkeypatch.setattr(clients, '_connect', lambda cfg: rpc)
    return cfg, source, target, rows, rpc


def complete_row(target, **changes):
    return dict(id='one', progress=1, state='stoppedUP', save_path=str(target.parent), **changes)


def test_idle_and_new_job_wake_promptly(transfer):
    cfg, source, target, rows, rpc = transfer
    stop, idle, queried = threading.Event(), threading.Event(), threading.Event()
    waits = []

    def wait(delay):
        waits.append(delay)
        idle.set()
        return transfers.WAKE.wait(delay)

    rows.side_effect = lambda cfg: queried.set() or []
    worker = threading.Thread(target=transfers.monitor, args=(stop,), kwargs={'wait': wait})
    worker.start()
    try:
        assert idle.wait(1)
        time.sleep(0.05)
        assert waits == [None]
        rows.assert_not_called()
        start = time.monotonic()
        transfers.record('one', cfg, source, target)
        assert queried.wait(1)
        print(f'Queued job reached provider in {(time.monotonic() - start) * 1000:.2f} ms')
    finally:
        stop.set()
        transfers.WAKE.set()
        worker.join(1)
    assert not worker.is_alive()
    rpc.torrents_delete.assert_not_called()
    assert source.is_dir() and 'one' in transfers.pending()


def test_error_backoff_and_redacted_status(transfer):
    cfg, source, target, rows, rpc = transfer
    transfers.record('one', cfg, source, target)
    rows.side_effect = RuntimeError('secret provider URL and username')
    stop, waits = threading.Event(), []
    elapsed = 0

    def wait(delay):
        nonlocal elapsed
        waits.append(delay)
        assert transfers.DIAGNOSTIC == {
            'state': 'client_unavailable', 'pending': 1, 'retry_at': elapsed + delay,
            'action': transfers.MESSAGES['client_unavailable']}
        elapsed += delay
        if elapsed >= 300:
            stop.set()

    transfers.monitor(stop, wait=wait, now=lambda: elapsed)
    assert waits == [5, 10, 20, 40, 80, 120, 120]
    assert rows.call_count == 7
    assert (source / 'chapter.m4b').read_bytes() == b'recording'
    assert 'one' in transfers.pending()
    rpc.torrents_delete.assert_not_called()
    print('300 virtual seconds: 7 provider calls; delays', waits)


def test_missing_moving_error_restart_and_duplicate_cleanup(transfer):
    cfg, source, target, rows, rpc = transfer
    transfers.record('one', cfg, source, target)
    assert transfers.finish_pending(cfg) == ('missing', 1)
    row = complete_row(target)
    rows.return_value = [row]
    for state, expected in [('moving', 'moving'), ('error', 'client_error'), ('stoppedUP', 'verification_pending')]:
        row['state'] = state
        assert transfers.finish_pending(cfg) == (expected, 1)
        assert (source / 'chapter.m4b').read_bytes() == b'recording'
        assert 'one' in transfers.pending()
    rpc.torrents_delete.assert_not_called()
    source.rename(target)
    source.mkdir()
    (source / 'chapter.m4b').write_bytes(b'recording')
    assert transfers.finish_pending(cfg) == ('verification_pending', 1)
    (source / 'chapter.m4b').unlink()
    rpc.torrents_delete.side_effect = RuntimeError('temporary failure')
    assert transfers.finish_pending(cfg) == ('cleanup_failed', 1)
    assert 'one' in transfers.pending()
    assert (target / 'chapter.m4b').read_bytes() == b'recording'
    rpc.reset_mock(side_effect=True)
    # Simulate a process restart: only the journal and files remain.
    transfers.ACKNOWLEDGED.clear()
    rows.return_value = []
    assert transfers.finish_pending(cfg) == ('missing', 1)
    rows.return_value = [row]
    with ThreadPoolExecutor(2) as pool:
        assert list(pool.map(lambda _: transfers.finish_pending(cfg), range(2))) == [('idle', 0)] * 2
    rpc.torrents_delete.assert_called_once_with(torrent_hashes='one', delete_files=False)
    assert transfers.pending() == {}
    assert (target / 'cover.jpg').read_bytes() == b'cover'


def test_successful_rpc_is_not_repeated_after_journal_write_failure(transfer, monkeypatch):
    cfg, source, target, rows, rpc = transfer
    transfers.record('one', cfg, source, target)
    source.rename(target)
    rows.return_value = [complete_row(target)]
    forget = transfers.forget
    monkeypatch.setattr(transfers, 'forget', Mock(side_effect=OSError))
    with pytest.raises(OSError):
        transfers.finish_pending(cfg)
    assert 'one' in transfers.pending()
    monkeypatch.setattr(transfers, 'forget', forget)
    assert transfers.finish_pending(cfg) == ('idle', 0)
    rpc.torrents_delete.assert_called_once()


def test_instruction_checker_catches_broken_links_and_commands(tmp_path):
    script = Path(__file__).resolve().parents[1] / '.agent-tools/check-instructions.py'
    checker = runpy.run_path(str(script))['missing_paths']
    (tmp_path / 'README.md').touch()
    assert checker('[ok](README.md) [missing](ios/README.md)\npython3 scripts/missing.py\n.venv/bin/python -m pytest tests -q', tmp_path) == [
        'ios/README.md', 'scripts/missing.py', 'tests']


def test_corrupt_journal_and_remote_configuration_leave_files_alone(transfer):
    cfg, source, target, rows, rpc = transfer
    transfers.journal().write_text('{interrupted')
    with pytest.raises(ValueError):
        transfers.record('one', cfg, source, target)
    assert transfers.journal().read_text() == '{interrupted'
    transfers.journal().unlink()
    transfers.record('one', cfg, source, target)
    remote = copy.deepcopy(cfg)
    remote['client']['url'] = 'https://example.invalid'
    assert transfers.finish_pending(remote) == ('configuration_changed', 1)
    rows.assert_not_called()
    rpc.torrents_delete.assert_not_called()
    assert (source / 'chapter.m4b').is_file() and not target.exists()


def test_symlink_destination_cannot_complete_transfer(transfer):
    cfg, source, target, rows, rpc = transfer
    transfers.record('one', cfg, source, target)
    other = target.parent / 'Other'
    source.rename(other)
    target.symlink_to(other, target_is_directory=True)
    rows.return_value = [complete_row(target)]
    assert transfers.finish_pending(cfg) == ('verification_pending', 1)
    assert (other / 'chapter.m4b').read_bytes() == b'recording'
    rpc.torrents_delete.assert_not_called()


def test_existing_dangling_destination_stops_both_move_paths(transfer):
    from listen_app import library
    cfg, source, target, rows, rpc = transfer
    target.symlink_to(target.parent / 'absent')
    row = dict(id='one', name=source.name, progress=1, save_path=str(source.parent), content_path=str(source))
    rows.return_value = [row]
    with pytest.raises(clients.ClientError, match='already exists'):
        clients.move_completed('one', cfg)
    with pytest.raises(clients.ClientError, match='already exists'):
        library.transfer(source.name, cfg)
    assert target.is_symlink()
    assert (source / 'chapter.m4b').is_file()
    assert transfers.pending() == {}
    rpc.torrents_set_location.assert_not_called()


def test_deluge_rejecting_cleanup_keeps_the_job(transfer):
    cfg, source, target, rows, rpc = transfer
    cfg['client']['type'] = 'deluge'
    transfers.record('one', cfg, source, target)
    rows.return_value = [complete_row(target)]
    source.rename(target)
    rpc.execute_call.return_value.result = False
    assert transfers.finish_pending(cfg) == ('cleanup_failed', 1)
    assert (target / 'chapter.m4b').is_file() and 'one' in transfers.pending()
