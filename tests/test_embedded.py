from contextlib import ExitStack
import hashlib
import importlib.util
import os
import socket
import socketserver
import struct
import sys
import threading
import time

import pytest

from listen_app.embedded import Engine, EngineError, endpoint, magnet_only


def test_proxy_and_magnet_inputs():
    assert endpoint('socks5://192.0.2.1:1080') == ('192.0.2.1', 1080)
    for url in ('http://192.0.2.1:1080', 'socks5://proxy.test:1080', 'socks5://user@127.0.0.1:1080'):
        with pytest.raises(ValueError):
            endpoint(url)
    magnet = magnet_only('magnet:?xt=urn:btih:abc&tr=https://tracker.example/announce&x.pe=203.0.113.1%3A6881&ws=https://example.net/data')
    assert 'x.pe=' not in magnet and 'ws=' not in magnet
    with pytest.raises(EngineError):
        magnet_only('magnet:?xt=urn:btih:abc&tr=udp://tracker.example/announce')


@pytest.mark.skipif(sys.platform != 'darwin' or importlib.util.find_spec('libtorrent') is None,
                    reason='requires the pinned native engine and macOS sandbox')
def test_download_through_authenticated_socks_and_fail_closed(tmp_path, monkeypatch):
    import http.server
    import select
    import libtorrent as lt

    class Tracker(http.server.BaseHTTPRequestHandler):
        def do_GET(self):
            self.send_response(200)
            self.end_headers()
            self.wfile.write(lt.bencode({'interval': 60, 'peers': socket.inet_aton('203.0.113.2') + struct.pack('!H', 6881)}))

        def log_message(self, *_):
            pass

    requests = []
    reject = threading.Event()

    class Socks(socketserver.StreamRequestHandler):
        def handle(self):
            version, count = self.rfile.read(2)
            methods = self.rfile.read(count)
            assert version == 5 and 2 in methods
            self.wfile.write(b'\x05\x02')
            version, count = self.rfile.read(2)
            user = self.rfile.read(count)
            password = self.rfile.read(self.rfile.read(1)[0])
            valid = version == 1 and user == b'fixture' and password == b'only-a-test' and not reject.is_set()
            self.wfile.write(b'\x01' + bytes([not valid]))
            if not valid:
                return
            header = self.rfile.read(4)
            if not header or header[1] != 1:
                return
            assert header[0] == 5
            if header[3] == 3:
                name = self.rfile.read(self.rfile.read(1)[0]).decode()
            else:
                assert header[3] == 1
                name = socket.inet_ntoa(self.rfile.read(4))
            port, = struct.unpack('!H', self.rfile.read(2))
            requests.append((name, port))
            destination = {'tracker.example': tracker.server_port, '203.0.113.2': seeder.listen_port()}[name]
            with socket.create_connection(('127.0.0.1', destination), timeout=2) as target:
                self.wfile.write(b'\x05\x00\x00\x01' + b'\x00' * 6)
                while True:
                    available, _, _ = select.select([self.request, target], [], [], 5)
                    if not available:
                        return
                    for source in available:
                        data = source.recv(65536)
                        if not data:
                            return
                        (target if source is self.request else self.request).sendall(data)

    content = b'listen. legal synthetic torrent fixture\n' * 1300
    source = tmp_path / 'seed'
    source.mkdir()
    (source / 'fixture.txt').write_bytes(content)
    files = lt.file_storage()
    lt.add_files(files, str(source / 'fixture.txt'))
    torrent = lt.create_torrent(files, flags=lt.create_torrent.v1_only)
    lt.set_piece_hashes(torrent, str(source))
    info = lt.torrent_info(torrent.generate())
    seeder = lt.session({'listen_interfaces': '127.0.0.1:0', 'enable_dht': False,
                         'enable_lsd': False, 'enable_upnp': False, 'enable_natpmp': False})
    params = lt.add_torrent_params()
    params.ti, params.save_path = info, str(source)
    params.flags |= lt.torrent_flags.seed_mode
    seed = seeder.add_torrent(params)
    deadline = time.monotonic() + 10
    while not seed.status().is_seeding and time.monotonic() < deadline:
        time.sleep(0.05)
    assert seed.status().is_seeding
    with ExitStack() as resources:
        tracker = resources.enter_context(http.server.ThreadingHTTPServer(('127.0.0.1', 0), Tracker))
        socks = resources.enter_context(socketserver.ThreadingTCPServer(('127.0.0.1', 0), Socks))
        socks.daemon_threads = True
        for server in (tracker, socks):
            threading.Thread(target=server.serve_forever, daemon=True).start()
            resources.callback(server.shutdown)
        monkeypatch.setenv('LISTEN_DATA_DIR', str(tmp_path / 'state'))
        if worker := os.environ.get('LISTEN_TEST_FROZEN_WORKER'):
            monkeypatch.setattr(sys, 'executable', worker)
            monkeypatch.setattr(sys, 'frozen', True, raising=False)
        config = {'client': {'url': f'socks5://127.0.0.1:{socks.server_address[1]}', 'username': 'fixture'}}
        engine = Engine(config, 'only-a-test')
        resources.callback(engine.close)
        assert engine.call('ready')
        uri = lt.make_magnet_uri(info) + '&tr=http%3A%2F%2Ftracker.example%2Fannounce'
        folder = tmp_path / 'download'
        key = engine.call('add', uri=uri, folder=str(folder))
        for _ in range(100):
            if engine.call('rows')[0]['progress'] == 1:
                break
            time.sleep(0.2)
        assert engine.call('rows')[0]['progress'] == 1, (requests, engine.call('rows'))
        assert hashlib.sha256((folder / 'fixture.txt').read_bytes()).digest() == hashlib.sha256(content).digest()
        assert ('tracker.example', 80) in requests
        assert ('203.0.113.2', 6881) in requests
        with pytest.raises(EngineError, match='already in Downloads'):
            engine.call('add', uri=uri, folder=str(tmp_path / 'duplicate'))
        engine.call('pause', key=key, paused=True)
        assert engine.call('rows')[0]['paused']
        reject.set()
        with pytest.raises(EngineError, match='rejected authentication'):
            engine.call('ready')
        with pytest.raises(EngineError, match='rejected authentication'):
            engine.call('pause', key=key, paused=False)
        assert engine.call('rows')[0]['paused']
        assert seed.is_valid()

    recovered = Engine(config, 'only-a-test')
    try:
        assert recovered.call('rows')[0]['paused']
        with pytest.raises(EngineError, match='SOCKS5 is unavailable'):
            recovered.call('pause', key=key, paused=False)
        recovered.call('remove', key=key)
        assert recovered.call('rows') == []
        assert (folder / 'fixture.txt').read_bytes() == content
    finally:
        recovered.close()
