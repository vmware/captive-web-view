# Run with Python 3
"""\
HTTP server that can be used as a back end. This server is based on the HTTP
back end to Local WebView applications.

Run it like:

    cd /path/where/you/cloned/cwvpiv/
    python3 ./httpBridge/cwvpiv.py
"""
#
# Standard library imports, in alphabetic order.
# Module for HTTP server, not imported here but handy to have the link.
# https://docs.python.org/3/library/http.server.html
#
# Module for Base 64 encoding certificate DER data.
# https://docs.python.org/3/library/base64.html
import base64
#
# Cryptographic hash module. Only used to generate a certificate thumbprint.
# https://docs.python.org/3/library/hashlib.html
import hashlib
#
# JSON module.
# https://docs.python.org/3/library/json.html
import json
#
# Module for OO path handling.
# https://docs.python.org/3/library/pathlib.html
from pathlib import Path
#
# Module for socket connections. Only used to generate a wrap-able socket for a
# TLS connection so that the peer certificate can be obtained.
# https://docs.python.org/3/library/socket.html
import socket
#
# Module for creating an unverified SSL/TLS context.
# Uses the undocumented _create_unverified_context() interface.
# TOTH https://stackoverflow.com/a/50949266/7657675
import ssl
#
# Module for spawning a process to run a command.
# https://docs.python.org/3/library/subprocess.html
import subprocess
#
# Module for manipulation of the import path.
# https://docs.python.org/3/library/sys.html#sys.path
import sys
#
# Temporary file module.
# https://docs.python.org/3/library/tempfile.html
from tempfile import NamedTemporaryFile
#
# Module for HTTP errors.
# https://docs.python.org/3/library/urllib.error.html
import urllib.error
#
# Module for URL requests.
# https://docs.python.org/3/library/urllib.request.html
import urllib.request
#
# Local Imports.
#
# Command handler base class.
from .base import CommandHandler

class Fetcher:
    _rootPath = Path().resolve().root
    # TOTH macOS `security` CLI and how to export the system CA stores:
    # https://stackoverflow.com/a/72053605/7657675
    _keychains = (
        (
            _rootPath, 'System', 'Library', 'Keychains'
            , 'SystemRootCertificates.keychain'
        ), (
            _rootPath, 'Library', 'Keychains', 'System.keychain'
        )
    )

    def __init__(self):
        self._pemPath = self.keychain_PEM()

        # Create a context in which the certificates from the keychain will be
        # used to verify the host.
        self._sslContext = ssl.SSLContext(ssl.PROTOCOL_TLS_CLIENT)
        self._sslContext.load_verify_locations(self._pemPath)

        # Note that host verification has to be switched on here for the peer
        # certificate to be available later, when the secure socket is
        # connected. Also, the host certificate has to be valid. For later
        # maybe, use something from this SO answer to get the certificate even
        # if it isn't valid.
        # https://stackoverflow.com/a/7691293/7657675

        # The sslContext no longer requires the PEM file but it's used later by
        # the openssl s_client.
        # self._pemPath.unlink()

    def keychain_PEM(self):
        # Export all the certificates from the system keychains into a single
        # temporary PEM file. Return the Path of the file.
        #
        # TOTH macOS `security` CLI and how to export the system CA stores:
        # https://stackoverflow.com/a/72053605/7657675
        #
        # TOTH creating a temporary file instead of loading it in the bash
        # profile:  
        # https://stackoverflow.com/a/70054211/7657675
        with NamedTemporaryFile(mode='w', delete=False, suffix=".pem") as file:
            pemPath = Path(file.name)

        for keychain in self._keychains:
            keychainPath = Path(*keychain)
            # TOTH macOS `security` CLI and how to export the system CA stores:
            # https://stackoverflow.com/a/72053605/7657675
            securityRun = subprocess.run(
                (
                    'security', 'export', '-k', keychainPath, '-t', 'certs'
                    , '-f', 'pemseq'
                ), stdout=subprocess.PIPE, text=True
            )
            print(f'"{keychainPath}" PEM {len(securityRun.stdout)} characters.')
            with pemPath.open('a') as file:
                file.write(securityRun.stdout)

        certificates = 0
        with pemPath.open() as file:
            while True:
                line = file.readline()
                if line == '':
                    break
                if line.startswith('--') and 'BEGIN CERTIFICATE' in line:
                    certificates += 1
        print(f'Keychain certificates: {certificates}.')

        return pemPath

    def fetch(self, parameters, httpHandler=None):
        # ToDo
        #
        # -   Make it check for the 'resource' key and other keys.
        url = urllib.parse.urlparse(parameters['resource'])
        host = url.hostname
        port = 443 if url.port is None else url.port
        self._log(httpHandler, f'fetch() {host} {port}.')

        peerCertEncoded, peerCertLength = self.get_peer_certificate(
            host, port, httpHandler)
        fetched = self.fetch_JSON(parameters, httpHandler)

        # url.netloc includes port, if there was one in the URL.
        self.openssl_thumbprint(
            host, f'{host}:{port}' if url.port is None else url.netloc
            , httpHandler)

        return {
            "fetched": fetched,
            "peerCertificateDER": peerCertEncoded,
            "peerCertificateLength": peerCertLength
        }

    def _log(self, httpHandler, message):
        if httpHandler is None:
            print(message)
        else:
            httpHandler.log_message("%s", message)
    
    def get_peer_certificate(self, host, port, httpHandler):
        # Open a socket connection in the context. It'd be nice to re-use this
        # connection for the ensuing HTTP request but there doesn't seem to be a
        # way to do that in the Python standard library. So this socket gets
        # closed after the certificate has been obtained, in binary and
        # dictionary form.
        sslSocket = self._sslContext.wrap_socket(
            socket.socket(socket.AF_INET), server_hostname=host)
        sslSocket.connect((host, port))
        peerCertBinary = sslSocket.getpeercert(True)
        peerCertDict = sslSocket.getpeercert(False)
        sslSocket.close()

        peerCertLength = len(peerCertBinary)
        peerCertMessage = "\n".join([
            f'{key} "{value}"' for key, value in peerCertDict.items()
        ])
        self._log(httpHandler
            , f'Peer certificate. Binary length: {peerCertLength}'
            f'. Dictionary:\n{peerCertMessage}')

        # TOTH Generate fingerprint with openssl and Python:
        # https://stackoverflow.com/q/70781380/7657675
        peerThumb = hashlib.sha1(peerCertBinary).hexdigest()
        self._log(httpHandler, f'Peer certificate thumbprint:\n{peerThumb}')
        # www.python.org SHA1 Fingerprint=B0:9E:C3:40:F4:19:78:D7:7A:76:84:79:0A:EF:84:0E:AD:DA:49:FD
        # B09EC340F41978D77A7684790AEF840EADDA49FD
        # b09ec340f41978d77a7684790aef840eadda49fd

        return base64.b64encode(peerCertBinary).decode('utf-8'), peerCertLength
    
    def fetch_JSON(self, parameters, httpHandler):
        # Fetch the resource in the context. ToDo:
        #
        # -   Make it handle different encoding schemes instead of assuming
        #     utf-8.
        # -   Make it handle HTTP failure.
        # -   Make it handle JSON formatting errors.

        request = urllib.request.Request(parameters['resource'])

        if 'options' in parameters:
            options = parameters['options']
            if 'method' in options:
                request.method = options['method']
            if 'body' in options:
                request.data = options['body'].encode()
                request.add_header('Content-Type', "application/json")
            if 'headers' in options:
                for header, value in options['headers'].items():
                    request.add_header(header, value)

        self._log(
            httpHandler,
            f'Request:\nhost "{request.host}"\nBody: {request.data}'
            f'\nselector "{request.selector}"'
            f'\nheaders {request.header_items()}'
        )

        opened = None
        try:
            opened = urllib.request.urlopen(request, context=self._sslContext)
            openedStatus = opened.status
            openedDetail = f'\n{opened.headers}'
        except urllib.error.HTTPError as error:
            openedStatus = error.code
            openedDetail = f' "{error.reason}"\n{error.headers}'
        self._log(httpHandler, f'Opened status: {openedStatus}{openedDetail}')

        fetched = None if opened is None else opened.read().decode('utf-8')
    
        self._log(
            httpHandler,
            f'Fetched length: {None if fetched is None else len(fetched)}.'
        )

        # ToDo: if openedStatus != 200 return error details.

        try:
            return json.loads(
                "{}" if fetched is None or len(fetched) == 0 else fetched
            )
        except json.decoder.JSONDecodeError as error:
            return {
                'JSONDecodeError': str(error), 'notJSON': fetched
            }
    
    def openssl_thumbprint(self, serverName, connectAddress, httpHandler):
        # TOTH Generate fingerprint with openssl and Python:
        # https://stackoverflow.com/q/70781380/7657675
        #
        # TOTH Terminate openssl client:
        # https://stackoverflow.com/a/34749879/7657675
        #
        # See also the MS documentation about thumbprint
        # https://docs.microsoft.com/en-us/dotnet/api/system.security.cryptography.x509certificates.x509certificate2.thumbprint?view=net-6.0#system-security-cryptography-x509certificates-x509certificate2-thumbprint

        # First run the openssl CLI to connect to the server. This logs the peer
        # certificate, and more besides.
        s_clientRun = subprocess.run(
            (
                'openssl', 's_client', '-servername', serverName, '-showcerts'
                , '-CAfile', str(self._pemPath), '-connect', connectAddress
            ), stdin=subprocess.DEVNULL, stdout=subprocess.PIPE
            , stderr=subprocess.PIPE, text=True
        )
        self._log(httpHandler, f'openssl s_client stderr\n{s_clientRun.stderr}')

        # Extract the PEM dump of the peer certificate from the s_client output.
        s_clientCertificatePEM = None
        for line in s_clientRun.stdout.splitlines(True):
            if line.startswith('--') and 'BEGIN CERTIFICATE' in line:
                s_clientCertificatePEM = []
            if s_clientCertificatePEM is not None:
                s_clientCertificatePEM.append(line)
            if line.startswith('--') and 'END CERTIFICATE' in line:
                break
        self._log(httpHandler
            , f'openssl s_client PEM lines: {len(s_clientCertificatePEM)}')

        # Pipe the PEM back into the openssl x509 CLI and have it calculate the
        # thumbprint aka fingerprint.
        x509Run = subprocess.run(
            ('openssl', 'x509', '-inform', 'PEM', '-fingerprint', '-noout')
            , input=''.join(s_clientCertificatePEM)
            , stdout=subprocess.PIPE, stderr=subprocess.STDOUT, text=True
        )
        self._log(httpHandler, f'openssl x509\n{x509Run.stdout}')

class FetchCommandHandler(CommandHandler):
    def __init__(self):
        self._fetcher = Fetcher()
        super().__init__()

    # Override.
    def __call__(self, commandObject, httpHandler):
        command, parameters = self.parseCommandObject(commandObject)

        if command != 'fetch':
            return None

        return self._fetcher.fetch(parameters, httpHandler)
