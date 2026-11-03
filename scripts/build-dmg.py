#!/usr/bin/env python3
"""Developer packaging only. No Python or dmgbuild is included in the app."""
from pathlib import Path
import plistlib
import struct
import subprocess
import tempfile
import uuid
import dmgbuild

root = Path(__file__).resolve().parent.parent
app = root / 'dist/SQLGarden.app'
with (app / 'Contents/Info.plist').open('rb') as f:
    version = plistlib.load(f)['CFBundleShortVersionString']
output = root / f'dist/SQLGarden-{version}-Universal.dmg'
if output.exists():
    raise SystemExit(f'Preserve the existing image before rebuilding: {output}')
subprocess.run(['codesign', '--verify', '--deep', '--strict', str(app)], check=True)
settings = dict(
    format='UDRW', filesystem='HFS+', files=[str(app)],
    symlinks={'Applications': '/Applications'}, icon=str(root / 'Resources/AppIcon.icns'),
    background=str(root / 'Resources/DMG-background.png'),
    window_rect=((160, 180), (720, 508)), default_view='icon-view',
    show_status_bar=False, show_tab_view=False, show_toolbar=False,
    show_pathbar=False, show_sidebar=False, arrange_by=None,
    icon_size=112, text_size=14, label_pos='bottom',
    icon_locations={'SQLGarden.app': (190, 220), 'Applications': (530, 220)},
    hide_extensions=[], include_icon_view_settings=True,
    include_list_view_settings=False, scroll_position=(0, 0))
with tempfile.TemporaryDirectory(prefix='sqlgarden-dmg-') as temporary:
    raw = Path(temporary) / 'layout.dmg'
    dmgbuild.build_dmg(str(raw), 'SQLGarden', settings=settings)
    # Finder's root-folder auto-open hint in both HFS+ volume headers.
    # Only mutate this newly-created, unmounted temporary image.
    data = bytearray(raw.read_bytes())
    assert data[512:520] == b'EFI PART', 'Expected GPT disk image'
    entry_lba, count, size = struct.unpack_from('<QII', data, 512 + 72)
    partitions = []
    for index in range(count):
        pos = entry_lba * 512 + index * size
        if str(uuid.UUID(bytes_le=bytes(data[pos:pos+16]))) == '48465300-0000-11aa-aa11-00306543ecac':
            partitions.append(struct.unpack_from('<QQ', data, pos + 32))
    assert len(partitions) == 1
    start, end = partitions[0]
    for header in (start*512+1024, (end+1)*512-1024):
        assert data[header:header+2] in (b'H+', b'HX')
        assert struct.unpack_from('>I', data, header+88)[0] == 0
        struct.pack_into('>I', data, header+88, 2)
    raw.write_bytes(data)
    subprocess.run(['hdiutil', 'convert', str(raw), '-format', 'UDZO', '-o', str(output)], check=True)
subprocess.run(['hdiutil', 'verify', str(output)], check=True)
print(f'DMG created: {output}')
