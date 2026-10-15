from __future__ import annotations

import ipaddress
import os
import socket
from urllib.parse import urljoin, urlsplit

import requests


DEFAULT_IMAGE_HOSTS = frozenset({
    "coto.com.ar", "cotodigital3.com.ar", "carrefour.com.ar",
    "carrefourar.vteximg.com.br", "lagallega.com.ar",
})
IMAGE_TYPES = frozenset({"image/jpeg", "image/png", "image/webp", "image/avif", "image/gif"})
MAX_IMAGE_BYTES = 5 * 1024 * 1024
MAX_REDIRECTS = 3


def _has_image_signature(content: bytes, content_type: str) -> bool:
    if content_type == "image/jpeg":
        return content.startswith(b"\xff\xd8\xff")
    if content_type == "image/png":
        return content.startswith(b"\x89PNG\r\n\x1a\n")
    if content_type == "image/gif":
        return content.startswith((b"GIF87a", b"GIF89a"))
    if content_type == "image/webp":
        return content.startswith(b"RIFF") and content[8:12] == b"WEBP"
    if content_type == "image/avif":
        return content[4:8] == b"ftyp" and b"avif" in content[8:32]
    return False


class ImageProxyError(Exception):
    def __init__(self, status_code: int, detail: str):
        self.status_code = status_code
        self.detail = detail
        super().__init__(detail)


def _allowed_hosts() -> set[str]:
    extra = os.getenv("CONVIENE_IMAGE_ALLOWED_HOSTS", "")
    return set(DEFAULT_IMAGE_HOSTS) | {host.strip().lower().rstrip(".") for host in extra.split(",") if host.strip()}


def validate_image_url(url: str) -> None:
    try:
        parsed = urlsplit(url)
        host = (parsed.hostname or "").lower().rstrip(".")
        port = parsed.port
    except ValueError as exc:
        raise ImageProxyError(400, "URL de imagen invalida") from exc
    if (parsed.scheme not in {"http", "https"} or not host or parsed.username or parsed.password
            or port not in {None, 80, 443}):
        raise ImageProxyError(400, "URL de imagen invalida")
    if not any(host == allowed or host.endswith("." + allowed) for allowed in _allowed_hosts()):
        raise ImageProxyError(403, "Dominio de imagen no permitido")
    try:
        addresses = socket.getaddrinfo(host, port or (443 if parsed.scheme == "https" else 80), type=socket.SOCK_STREAM)
        if not addresses or any(not ipaddress.ip_address(address[4][0]).is_global for address in addresses):
            raise ImageProxyError(403, "Destino de imagen no permitido")
    except (OSError, ValueError) as exc:
        raise ImageProxyError(502, "No se pudo resolver la imagen") from exc


def fetch_image(url: str) -> tuple[bytes, str]:
    session = requests.Session()
    session.trust_env = False
    try:
        for _ in range(MAX_REDIRECTS + 1):
            validate_image_url(url)
            try:
                response = session.get(
                    url,
                    headers={"User-Agent": "Conviene/1.1", "Accept": "image/avif,image/webp,image/png,image/jpeg,image/gif"},
                    timeout=(3, 10), stream=True, allow_redirects=False,
                )
                with response:
                    if response.is_redirect:
                        location = response.headers.get("location")
                        if not location:
                            raise ImageProxyError(502, "Redireccion de imagen invalida")
                        url = urljoin(url, location)
                        continue
                    response.raise_for_status()
                    content_type = response.headers.get("content-type", "").split(";", 1)[0].strip().lower()
                    if content_type not in IMAGE_TYPES:
                        raise ImageProxyError(415, "La URL no devolvio una imagen compatible")
                    try:
                        length = int(response.headers.get("content-length", "0"))
                    except ValueError:
                        length = 0
                    if length > MAX_IMAGE_BYTES:
                        raise ImageProxyError(413, "La imagen supera el limite permitido")
                    chunks, size = [], 0
                    for chunk in response.iter_content(chunk_size=65536):
                        size += len(chunk)
                        if size > MAX_IMAGE_BYTES:
                            raise ImageProxyError(413, "La imagen supera el limite permitido")
                        chunks.append(chunk)
                    content = b"".join(chunks)
                    if not _has_image_signature(content, content_type):
                        raise ImageProxyError(415, "El contenido no es una imagen valida")
                    return content, content_type
            except requests.RequestException as exc:
                raise ImageProxyError(502, "No se pudo cargar la imagen") from exc
        raise ImageProxyError(502, "Demasiadas redirecciones de imagen")
    finally:
        session.close()
