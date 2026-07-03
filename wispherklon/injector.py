"""Metin enjeksiyonu — pano + Cmd-V simülasyonu.

Akış: mevcut pano içeriğini kaydet → metni panoya koy → Quartz CGEventPost
ile Cmd-V bas → kısa bekle → eski pano içeriğini geri yükle.

Karakter karakter klavye simülasyonu macOS'ta Türkçe karakterlerde güvenilmez
olduğu için (elenmiştir) pano yolu kullanılır.
"""

import time

from AppKit import NSPasteboard, NSStringPboardType
from Quartz import (
    CGEventCreateKeyboardEvent,
    CGEventPost,
    CGEventSetFlags,
    kCGEventFlagMaskCommand,
    kCGHIDEventTap,
)

from . import config

_V_KEYCODE = 9  # ANSI 'v'


def _paste_keystroke():
    """Cmd-V tuş kombinasyonunu gönder."""
    down = CGEventCreateKeyboardEvent(None, _V_KEYCODE, True)
    CGEventSetFlags(down, kCGEventFlagMaskCommand)
    CGEventPost(kCGHIDEventTap, down)

    up = CGEventCreateKeyboardEvent(None, _V_KEYCODE, False)
    CGEventSetFlags(up, kCGEventFlagMaskCommand)
    CGEventPost(kCGHIDEventTap, up)


def inject(text: str):
    """Metni aktif uygulamanın imleç konumuna yaz, panoyu geri yükle."""
    if not text:
        return

    pb = NSPasteboard.generalPasteboard()
    # Eski içeriği (düz metin) sakla — sadece string tipini geri yükleriz.
    old = pb.stringForType_(NSStringPboardType)

    pb.clearContents()
    pb.setString_forType_(text, NSStringPboardType)

    # Panonun yerleşmesi için minik bir soluk, sonra yapıştır.
    time.sleep(0.02)
    _paste_keystroke()

    # Hedef uygulama yapıştırmayı bitirsin, sonra eski panoyu geri koy.
    time.sleep(config.PASTE_RESTORE_DELAY)
    pb.clearContents()
    if old is not None:
        pb.setString_forType_(old, NSStringPboardType)
