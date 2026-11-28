"""Proxy-only torrent worker. The app exchanges commands over anonymous pipes."""
from __future__ import annotations

import errno
import importlib.util
import ipaddress
import json
import select
import socket
import socketserver
import subprocess
import sys
import threading
from pathlib import Path
from urllib.parse import parse_qsl, urlencode, urlsplit

from . import settings


class EngineError(RuntimeError):
    pass


def available():
    return sys.platform == 'darwin' and importlib.util.find_spec('libtorrent') is not None


def endpoint(url):
    parsed = urlsplit(url)
    address = ipaddress.ip_address(parsed.hostname or '')
    if (parsed.scheme != 'socks5' or address.version != 4 or not parsed.port
        or parsed.username or parsed.password or parsed.path or parsed.query or parsed.fragment
        or address.is_unspecified or address.is_multicast):
        raise ValueError('Enter a SOCKS5 URL with an IPv4 address and port, without credentials.')
    return str(address), parsed.port


def magnet_only(uri):
    parsed = urlsplit(uri)
    if parsed.scheme != 'magnet' or len(uri) > 16384:
        raise EngineError('The built-in engine needs a magnet link with an HTTP or HTTPS tracker.')
    fields = [(key, value) for key, value in parse_qsl(parsed.query) if key in ('xt', 'dn', 'tr')]
    fields = [(key, value) for key, value in fields
              if key != 'tr' or urlsplit(value).scheme in ('http', 'https')]
    if not any(key == 'tr' for key, _ in fields):
        raise EngineError('The built-in engine needs a magnet link with an HTTP or HTTPS tracker.')
    return 'magnet:?' + urlencode(fields)


class Relay(socketserver.ThreadingTCPServer):
    daemon_threads = True
    request_queue_size = 32

    def __init__(self, upstream):
        self.upstream = upstream
        self.closed = threading.Event()
        self.slots = threading.BoundedSemaphore(64)
        super().__init__(('127.0.0.1', 0), Forward)


    def process_request(self, request, client_address):
        if not self.slots.acquire(blocking=False):
            self.shutdown_request(request)
            return
        try:
            super().process_request(request, client_address)
        except BaseException:
            self.slots.release()
            raise

    def process_request_thread(self, request, client_address):
        try:
            super().process_request_thread(request, client_address)
        finally:
            self.slots.release()


class Forward(socketserver.BaseRequestHandler):
    def handle(self):
        try:
            with socket.create_connection(self.server.upstream, timeout=5) as upstream:
                self.request.settimeout(5)
                while not self.server.closed.is_set():
                    ready, _, _ = select.select([upstream, self.request], [], [], 1)
                    for source in ready:
                        data = source.recv(65536)
                        if not data:
                            return
                        target = self.request if source is upstream else upstream
                        target.sendall(data)
        except OSError:
            return


class Engine:
    def __init__(self, cfg, password):
        if not available():
            raise EngineError('This build does not include the protected torrent engine.')
        address = endpoint(cfg['client']['url'])
        self.relay = Relay(address)
        port = self.relay.server_address[1]
        self.thread = threading.Thread(target=self.relay.serve_forever, daemon=True)
        self.thread.start()
        # libtorrent needs a bound UDP socket to schedule announces. The sandbox
        # still denies inbound traffic and every outbound UDP send.
        profile = (
            '(version 1)(allow default)(deny network*)'
            '(allow network-bind (local udp "*:*"))'
            f'(allow network-outbound (remote tcp "localhost:{port}"))'
        )
        entry = [] if getattr(sys, 'frozen', False) else [str(Path(__file__).resolve().parents[1] / 'listen_server.py')]
        self.process = None
        try:
            self.process = subprocess.Popen(
                ['/usr/bin/sandbox-exec', '-p', profile, sys.executable, *entry, '--embedded-worker'],
                stdin=subprocess.PIPE, stdout=subprocess.PIPE, stderr=subprocess.DEVNULL,
            )
            self.call('setup', port=port, username=cfg['client']['username'], password=password,
                      root=str(settings.data_dir()))
        except BaseException:
            self.close()
            raise

    def call(self, action, **args):
        try:
            self.process.stdin.write(json.dumps({'action': action, **args}).encode() + b'\n')
            self.process.stdin.flush()
            if not select.select([self.process.stdout], [], [], 15)[0]:
                raise OSError('timeout')
            response = json.loads(self.process.stdout.readline())
        except (OSError, ValueError) as exc:
            raise ConnectionError('The protected torrent worker is unavailable.') from exc
        if 'error' in response:
            raise EngineError(response['error'])
        return response['result']

    def close(self):
        self.relay.closed.set()
        if self.process is not None:
            self.process.terminate()
            try:
                self.process.wait(timeout=3)
            except subprocess.TimeoutExpired:
                self.process.kill()
                self.process.wait()
            self.process.stdin.close()
            self.process.stdout.close()
        self.relay.shutdown()
        self.relay.server_close()


_lock = threading.RLock()
_engine = None
_identity = None


def reset():
    global _engine, _identity
    with _lock:
        if _engine is not None:
            _engine.close()
        _engine = _identity = None


def command(cfg, action, **args):
    global _engine, _identity
    with _lock:
        current = settings.load()
        if current['client'] != cfg['client'] or current['client']['type'] != 'embedded':
            raise EngineError('Save the built-in engine settings before using it.')
        password = settings.get_password(cfg)
        identity = (cfg['client']['url'], cfg['client']['username'], password)
        if _engine is not None and (_identity != identity or _engine.process.poll() is not None):
            reset()
        if _engine is None:
            _engine = Engine(cfg, password)
            _identity = identity
        try:
            return _engine.call(action, **args)
        except ConnectionError as exc:
            reset()
            raise EngineError(str(exc)) from exc


class Worker:
    def setup(self, port, username, password, root):
        import libtorrent as lt

        # This probe checks the same enforced seatbelt policy the engine uses.
        with socket.socket() as probe:
            if probe.connect_ex(('127.0.0.1', 1)) != errno.EPERM:
                raise EngineError('macOS did not enforce the torrent network guard.')
        self.port, self.username, self.password = port, username, password
        self.lt = lt
        self.journal = Path(root) / 'embedded-torrents.json'
        self.jobs = settings.read_json(self.journal, {})
        self.session = lt.session({
            'proxy_type': int(lt.proxy_type_t.socks5_pw if username else lt.proxy_type_t.socks5),
            'proxy_hostname': '127.0.0.1', 'proxy_port': port,
            'proxy_username': username, 'proxy_password': password,
            'proxy_hostnames': True, 'proxy_peer_connections': True, 'proxy_tracker_connections': True,
            'enable_dht': False, 'enable_lsd': False, 'enable_upnp': False, 'enable_natpmp': False,
            'enable_outgoing_utp': False, 'enable_incoming_utp': False, 'enable_incoming_tcp': False,
            'listen_interfaces': '127.0.0.1:0', 'anonymous_mode': True, 'ssrf_mitigation': True,
        })
        self.handles = {}
        for key, job in self.jobs.items():
            self.attach(key, job)
        return True

    def ready(self):
        try:
            with socket.create_connection(('127.0.0.1', self.port), timeout=4) as connection:
                incoming = connection.makefile('rb')
                method = 2 if self.username else 0
                connection.sendall(bytes((5, 1, method)))
                if incoming.read(2) != bytes((5, method)):
                    raise OSError('proxy negotiation failed')
                if method:
                    user, password = self.username.encode(), self.password.encode()
                    if not 0 < len(user) < 256 or not 0 < len(password) < 256:
                        raise OSError('invalid SOCKS5 credentials')
                    connection.sendall(bytes((1, len(user))) + user + bytes((len(password),)) + password)
                    if incoming.read(2) != b'\x01\x00':
                        raise OSError('proxy authentication failed')
        except OSError as exc:
            raise EngineError('SOCKS5 is unavailable or rejected authentication. Downloads require the proxy.') from exc
        return True

    def attach(self, key, job):
        params = self.lt.parse_magnet_uri(job['magnet'])
        params.save_path = job['folder']
        params.flags |= (self.lt.torrent_flags.disable_dht | self.lt.torrent_flags.disable_lsd |
                         self.lt.torrent_flags.disable_pex | self.lt.torrent_flags.override_web_seeds)
        if job.get('paused'):
            params.flags &= ~self.lt.torrent_flags.auto_managed
            params.flags |= self.lt.torrent_flags.paused
        self.handles[key] = self.session.add_torrent(params)

    def add(self, uri, folder):
        self.ready()
        uri = magnet_only(uri)
        hashes = self.lt.parse_magnet_uri(uri).info_hashes
        key = str(hashes.v1 if hashes.has_v1() else hashes.v2)
        if key in self.jobs:
            raise EngineError('This download is already in Downloads.')
        destination = Path(folder)
        try:
            destination.mkdir()
        except FileExistsError as exc:
            raise EngineError('The download destination already exists. No files were overwritten.') from exc
        job = {'magnet': uri, 'folder': folder}
        updated = {**self.jobs, key: job}
        try:
            self.attach(key, job)
            settings.atomic_json(self.journal, updated)
        except Exception:
            if key in self.handles:
                self.session.remove_torrent(self.handles.pop(key))
            try:
                destination.rmdir()
            except OSError:
                pass
            raise
        self.jobs = updated
        return key

    def rows(self):
        result = []
        for key, handle in self.handles.items():
            status = handle.status()
            folder = Path(self.jobs[key]['folder'])
            info = handle.torrent_file()
            content = ''
            if info is not None and info.num_files() > 0:
                content = str(folder / Path(info.files().file_path(0)).parts[0])
            result.append(dict(id=key, name=status.name, progress=status.progress, state=str(status.state),
                               size=status.total_wanted, download_speed=status.download_payload_rate,
                               upload_speed=status.upload_payload_rate, seeds=status.num_seeds,
                               peers=status.num_peers, availability=None, save_path=str(folder), content_path=content,
                               embedded=True, paused=self.jobs[key].get('paused', False)))
        return result

    def pause(self, key, paused):
        if not paused:
            self.ready()
        if key not in self.handles:
            raise EngineError('This download is no longer in Downloads.')
        updated = {**self.jobs, key: {**self.jobs[key], 'paused': paused}}
        settings.atomic_json(self.journal, updated)
        self.jobs = updated
        handle = self.handles[key]
        if paused:
            handle.unset_flags(self.lt.torrent_flags.auto_managed)
            handle.pause()
        else:
            handle.set_flags(self.lt.torrent_flags.auto_managed)
            handle.resume()
        return True

    def remove(self, key):
        if key not in self.handles:
            raise EngineError('This download is no longer in Downloads.')

        updated = {k: v for k, v in self.jobs.items() if k != key}
        settings.atomic_json(self.journal, updated)
        self.session.remove_torrent(self.handles.pop(key))
        self.jobs = updated
        return True


def worker_main():
    worker = Worker()
    for line in sys.stdin:
        try:
            request = json.loads(line)
            name = request.pop('action')
            if name not in ('setup', 'ready', 'add', 'rows', 'pause', 'remove'):
                raise EngineError('Unsupported torrent action.')
            response = {'result': getattr(worker, name)(**request)}
        except EngineError as error:
            response = {'error': str(error)}
        except Exception:
            response = {'error': 'The protected torrent worker could not complete this action.'}
        print(json.dumps(response), flush=True)
