#!/usr/bin/env python3
"""Check the local image API without printing credentials or vendor response bodies.

The default operation only requests the model list. --generate explicitly sends
one photo-edit request, which can incur the provider's image-generation charge.
"""
import argparse
import base64
from datetime import datetime, timezone
import hashlib
import json
import mimetypes
from pathlib import Path
import subprocess
import sys
import time
from urllib.parse import urlsplit
from urllib.request import ProxyHandler, Request, build_opener
from urllib.error import HTTPError, URLError


def curl_request(url, key, *, direct=False, fields=(), timeout=30):
    if any(char in key for char in '\r\n'):
        raise ValueError('invalid_key_format')
    # The secret goes through stdin, never through argv, shell expansion, or logs.
    escaped = key.replace('\\', '\\\\').replace('"', '\\"')
    config = 'header = "Authorization: Bearer ' + escaped + '"\n'
    command = ['curl', '--config', '-', '--http1.1', '--silent', '--show-error',
               '--connect-timeout', '12', '--max-time', str(timeout),
               '--write-out', '\n%{http_code}']
    if direct:
        command += ['--noproxy', '*']
    for name, value in fields:
        command += ['--form' if name == 'image' else '--form-string', name + '=' + value]
    result = subprocess.run(command + [url], input=config.encode(), capture_output=True)
    if result.returncode:
        # curl stderr and upstream bodies are deliberately not forwarded.
        return {'transport_exit_code': result.returncode}, None
    body, status = result.stdout.rsplit(b'\n', 1)
    metadata = {'http_status': int(status)}
    try:
        return metadata, json.loads(body)
    except (ValueError, UnicodeDecodeError):
        metadata['error'] = 'non_json_response'
        return metadata, None


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    root = Path(__file__).resolve().parent.parent
    parser.add_argument('--config', type=Path, default=root / 'Resources/image-generation.json')
    parser.add_argument('--direct', action='store_true', help='Bypass configured HTTP proxies.')
    parser.add_argument('--generate', action='store_true', help='Send one billable photo-edit request.')
    parser.add_argument('--image', type=Path, help='A test photo you may send to the configured provider.')
    parser.add_argument('--output', type=Path, default=root / 'outputs/image-api-smoke')
    parser.add_argument('--timeout-seconds', type=int,
                        help='Override the edit/download timeout, clamped to 30–300 seconds.')
    args = parser.parse_args()
    summary = {'network_mode': 'without_http_proxy' if args.direct else 'default',
               'started_at_utc': datetime.now(timezone.utc).isoformat(),
               'generated': False, 'edit_request_count': 0}
    try:
        config = json.loads(args.config.read_text())
        endpoint = config['endpoint'].rstrip('/')
        parsed = urlsplit(endpoint)
        if (parsed.scheme != 'https' or not parsed.hostname or parsed.username
                or parsed.password or parsed.query or parsed.fragment):
            raise ValueError('expected_https_endpoint_without_credentials_or_query')
        key = config.get('apiKey', '').strip()
        model = config.get('model', '').strip()
        if not key or not model:
            raise ValueError('missing_key_or_model')
        if not endpoint.endswith('/images/edits'):
            raise ValueError('expected_image_edit_endpoint')
        base = endpoint[:-len('/images/edits')]
        summary.update({'provider_host': parsed.hostname, 'model': model})
        status, payload = curl_request(base + '/models', key, direct=args.direct)
        summary['model_check'] = status
        if status.get('http_status') != 200 or not isinstance(payload, dict):
            summary['error'] = 'model_check_failed'
            return summary, 1
        models = [entry.get('id') for entry in payload.get('data', []) if isinstance(entry, dict)]
        summary['model_available'] = model in models
        if model not in models:
            summary['error'] = 'configured_model_unavailable'
            return summary, 1
        if not args.generate:
            return summary, 0
        if args.image is None or not args.image.is_file():
            raise ValueError('generate_requires_existing_image')
        image = args.image.resolve()
        mime = mimetypes.guess_type(image.name)[0]
        if mime not in {'image/jpeg', 'image/png', 'image/webp'}:
            raise ValueError('unsupported_input_image')
        timeout = min(max(int(args.timeout_seconds if args.timeout_seconds is not None
                              else config.get('timeoutSeconds', 120)), 30), 300)
        summary.update({'timeout_seconds': timeout, 'input': str(image),
                        'input_sha256': hashlib.sha256(image.read_bytes()).hexdigest()})
        # Quote the filename in curl's multipart syntax, independent of shell quoting.
        filename = str(image).replace('\\', '\\\\').replace('"', '\\"')
        fields = [('model', model), ('n', '1'), ('size', config.get('size', '1024x1024')),
                  ('image', '@"' + filename + '";type=' + mime),
                  ('prompt', 'Edit this exact photographed desk into an organized version. '
                   'Preserve the camera angle, desk shape, room, lighting, existing furniture, '
                   'and every visible personal possession. Group books and stationery neatly, '
                   'keep electronics and cables usable, and clear a practical central work area. '
                   'Do not add furniture or remove possessions. Photorealistic, no text overlays.')]
        started = time.monotonic()
        summary['edit_request_count'] = 1
        status, payload = curl_request(endpoint, key, direct=args.direct, fields=fields,
                                       timeout=timeout)
        summary['edit_request'] = status
        summary['elapsed_seconds'] = round(time.monotonic() - started, 2)
        if status.get('http_status') != 200 or not isinstance(payload, dict):
            summary['error'] = 'edit_request_failed'
            return summary, 1
        entries = payload.get('data', [])
        if not entries or not isinstance(entries[0], dict):
            summary['error'] = 'expected_base64_image_response'
            return summary, 1
        first = entries[0]
        if first.get('b64_json'):
            summary['response_mode'] = 'b64_json'
            data = base64.b64decode(first['b64_json'], validate=True)
        elif isinstance(first.get('url'), str):
            summary['response_mode'] = 'https_url'
            image_url = urlsplit(first['url'])
            if image_url.scheme != 'https' or not image_url.hostname or image_url.username or image_url.password:
                summary['error'] = 'unsafe_image_url'
                return summary, 1
            image_request = Request(first['url'], headers={'Accept': 'image/*'})
            # Match --direct for the image CDN as well as the edit request.
            opener = build_opener(ProxyHandler({})) if args.direct else build_opener()
            try:
                with opener.open(image_request, timeout=timeout) as response:
                    summary['image_download'] = {'http_status': response.status}
                    if not 200 <= response.status < 300:
                        summary['error'] = 'image_download_failed'
                        return summary, 1
                    data = response.read(32 * 1024 * 1024 + 1)
            except (HTTPError, URLError, TimeoutError) as error:
                summary['image_download'] = {'error_type': type(error).__name__}
                summary['error'] = 'image_download_failed'
                return summary, 1
            if len(data) > 32 * 1024 * 1024:
                summary['error'] = 'image_too_large'
                return summary, 1
        else:
            summary['error'] = 'unsupported_image_response'
            return summary, 1
        if data.startswith(b'\x89PNG\r\n\x1a\n'):
            extension = '.png'
        elif data.startswith(b'\xff\xd8\xff'):
            extension = '.jpg'
        elif data.startswith(b'RIFF') and data[8:12] == b'WEBP':
            extension = '.webp'
        else:
            raise ValueError('unrecognized_image_bytes')
        args.output.mkdir(parents=True, exist_ok=True)
        destination = args.output / ('organized-desk' + extension)
        destination.write_bytes(data)
        summary.update({'generated': True, 'output': str(destination.resolve()),
                        'output_bytes': len(data), 'output_sha256': hashlib.sha256(data).hexdigest(),
                        'finished_at_utc': datetime.now(timezone.utc).isoformat()})
        return summary, 0
    except (KeyError, ValueError, OSError) as error:
        # Exception messages may include local paths or provider content: keep only the type.
        summary.update({'error': 'local_config_or_response_error', 'error_type': type(error).__name__})
        return summary, 1
    finally:
        # Preserve failed attempts too, without URLs, credentials, or upstream bodies.
        summary.setdefault('finished_at_utc', datetime.now(timezone.utc).isoformat())
        try:
            args.output.mkdir(parents=True, exist_ok=True)
            (args.output / 'summary.json').write_text(
                json.dumps(summary, ensure_ascii=False, indent=2) + '\n')
        except OSError:
            summary['summary_write_failed'] = True


if __name__ == '__main__':
    result, code = main()
    print(json.dumps(result, ensure_ascii=False, indent=2))
    sys.exit(code)
