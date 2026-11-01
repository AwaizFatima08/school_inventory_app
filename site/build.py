#!/usr/bin/env python3
"""Builds school-supplies.homilabs.org into site/dist.

Static pages (no cookies, no trackers, no third-party requests) plus the
Flutter web app under /app/ when build/web exists.

    flutter build web --release --base-href /app/ --no-web-resources-cdn --pwa-strategy=none
    python3 site/build.py
"""
import pathlib
import shutil

from content import DELETION, HOME, PRIVACY, TERMS

ROOT = pathlib.Path(__file__).parent
DIST = ROOT / 'dist'
WEB = ROOT.parent / 'build' / 'web'
ICON = ROOT.parent / 'web' / 'icons' / 'Icon-192.png'
FAVICON = ROOT.parent / 'web' / 'favicon.png'
SITE = 'https://school-supplies.homilabs.org'

PAGE = '''<!doctype html>
<html lang="en">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>{title}</title>
<meta name="description" content="{description}">
<link rel="canonical" href="{site}/{path}">
<meta property="og:title" content="{title}">
<meta property="og:description" content="{description}">
<meta property="og:type" content="website">
<meta property="og:url" content="{site}/{path}">
<meta property="og:image" content="{site}/og.png">
<link rel="icon" type="image/png" href="/favicon.png">
<link rel="stylesheet" href="/style.css">
</head>
<body>
<header class="top"><div class="wrap">
<a class="brand" href="/"><img src="/icon.png" alt="" width="36" height="36">School Inventory</a>
<a class="btn small" href="/app/">Open web app</a>
</div></header>
<main>{body}</main>
<footer><div class="wrap">
<a href="/privacy.html">Privacy</a>
<a href="/terms.html">Terms</a>
<a href="/delete-account.html">Delete account</a>
<a href="mailto:support@homilabs.org">support@homilabs.org</a>
<span>© HomiLabs</span>
</div></footer>
</body>
</html>
'''

PAGES = {
    'index.html': ('School Inventory: janitorial stock control for schools',
                   'Replace the paper register: enter demand slips, approve, issue and track janitorial stock from phone or desktop.',
                   HOME),
    'privacy.html': ('Privacy Policy | School Inventory',
                     'What School Inventory collects, why, and how to delete it.', PRIVACY),
    'terms.html': ('Terms of Use | School Inventory',
                   'The terms for using School Inventory.', TERMS),
    'delete-account.html': ('Delete your account | School Inventory',
                            'How to delete your School Inventory account and data.', DELETION),
}


def main():
    if DIST.exists():
        shutil.rmtree(DIST)
    DIST.mkdir()
    for path, (title, description, body) in PAGES.items():
        html = PAGE.format(title=title, description=description, body=body,
                           site=SITE, path='' if path == 'index.html' else path)
        (DIST / path).write_text(html, encoding='utf-8')
    for f in (ROOT / 'static').iterdir():
        shutil.copy(f, DIST / f.name)
    shutil.copy(ICON, DIST / 'icon.png')
    shutil.copy(FAVICON, DIST / 'favicon.png')
    (DIST / 'robots.txt').write_text(
        f'User-agent: *\nDisallow: /app/\nSitemap: {SITE}/sitemap.xml\n')
    urls = ''.join(f'<url><loc>{SITE}/{"" if p == "index.html" else p}</loc></url>'
                   for p in PAGES)
    (DIST / 'sitemap.xml').write_text(
        '<?xml version="1.0" encoding="UTF-8"?>'
        f'<urlset xmlns="http://www.sitemaps.org/schemas/sitemap/0.9">{urls}</urlset>')
    if WEB.exists():
        shutil.copytree(WEB, DIST / 'app')
        (DIST / 'app' / '.htaccess').write_text((ROOT / 'app.htaccess').read_text())
    archive = shutil.make_archive(str(ROOT / 'school-supplies-site'), 'zip', DIST)
    print('built', DIST, '->', archive)


if __name__ == '__main__':
    main()
