# Uso: view.py PAGINA [modo]
#  modo "grid": página inteira com grade de coordenadas (px nativos 794x1122)
#  modo "x0,y0,x1,y1[@escala]": recorte ampliado e com contraste reforçado
import sys
from PIL import Image, ImageDraw, ImageOps, ImageFilter
base = '/tmp/claude-0/-home-user-olaola/506d9357-0233-5e61-ba9a-2093b0ac2642/scratchpad/'
p = int(sys.argv[1]); mode = sys.argv[2] if len(sys.argv) > 2 else 'grid'
im = Image.open(base + 'orig/p-%03d.png' % p).convert('L')

def enhance(g):
    g = ImageOps.autocontrast(g, cutoff=(1, 0.5))
    return g.point(lambda v: int(255 * (v / 255) ** 1.6))

if mode == 'grid':
    g = enhance(im).convert('RGB'); d = ImageDraw.Draw(g)
    W, H = g.size
    for x in range(0, W, 50):
        d.line([(x, 0), (x, H)], fill=(255, 150, 150) if x % 100 == 0 else (255, 215, 215), width=1)
        if x % 100 == 0: d.text((x + 2, 2), str(x), fill=(220, 0, 0)); d.text((x + 2, H - 12), str(x), fill=(220, 0, 0))
    for y in range(0, H, 50):
        d.line([(0, y), (W, y)], fill=(150, 150, 255) if y % 100 == 0 else (215, 215, 255), width=1)
        if y % 100 == 0: d.text((2, y + 2), str(y), fill=(0, 0, 220)); d.text((W - 30, y + 2), str(y), fill=(0, 0, 220))
    out = base + 'view/p%03d_grid.png' % p
else:
    box, _, sc = mode.partition('@'); sc = float(sc or 2)
    x0, y0, x1, y1 = map(int, box.split(','))
    c = im.crop((x0, y0, x1, y1))
    c = c.resize((int((x1 - x0) * sc), int((y1 - y0) * sc)), Image.LANCZOS)
    g = enhance(c)
    out = base + 'view/p%03d_%d_%d_%d_%d.png' % (p, x0, y0, x1, y1)
g.save(out); print(out)
