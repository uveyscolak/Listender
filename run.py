#!/usr/bin/env python3
"""Listender giriş noktası."""

import sys


def _redirect_output_if_bundled():
    """Paketli .app'te (tty yok) tüm print/traceback'i teşhis loguna akıt.

    Finder'dan açılan uygulamanın stdout'u kaybolur — hata teşhisi için
    /tmp/listender.log tek pencere.
    """
    try:
        if sys.stdout is None or not sys.stdout.isatty():
            # encoding ŞART: Finder'dan açılan .app'te yerel C/ASCII'dir —
            # Türkçe karakterli print UnicodeEncodeError ile worker thread'i
            # öldürüyordu (2026-07-03, dikteyi sessizce kıran bug).
            log = open("/tmp/listender.log", "a", buffering=1,
                       encoding="utf-8", errors="replace")
            sys.stdout = sys.stderr = log
            print("--- Listender başlıyor ---", flush=True)
    except Exception:
        pass


if __name__ == "__main__":
    _redirect_output_if_bundled()
    from listender.app import main

    main()
