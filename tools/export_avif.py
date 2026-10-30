"""Convert docs/images/*.gif previews to animated AVIF (same frames, timing and size; no resampling).
Needs Pillow >= 11.3 with AVIF support. Usage: python3 tools/export_avif.py [docs/images]"""
import glob, os, sys
from PIL import Image, ImageSequence
d = sys.argv[1] if len(sys.argv) > 1 else os.path.join(os.path.dirname(__file__), '..', 'docs', 'images')
for g in sorted(glob.glob(os.path.join(d, '*.gif'))):
    im = Image.open(g)
    alpha = im.info.get('transparency') is not None
    fr, du = [], []
    for f in ImageSequence.Iterator(im):
        fr.append(f.convert('RGBA' if alpha else 'RGB')); du.append(f.info.get('duration', 100))
    out = g[:-4] + '.avif'
    fr[0].save(out, save_all=True, append_images=fr[1:], duration=du, loop=0,
               quality=100, subsampling='4:4:4', speed=4)
    print(f'{os.path.basename(out)}: {len(fr)} frames, alpha={alpha}')
