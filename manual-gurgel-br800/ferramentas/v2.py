# Uso: v2.py PAG [PAG...]  -> gera view/pNNN_a.png (metade superior) e _b.png (inferior),
# ampliadas 1.9x, com réguas nas bordas em coordenadas nativas (794x1122).
import sys
from PIL import Image, ImageDraw, ImageOps
base = '/tmp/claude-0/-home-user-olaola/506d9357-0233-5e61-ba9a-2093b0ac2642/scratchpad/'
SC = 1.9; M = 34
def enhance(g):
    g = ImageOps.autocontrast(g, cutoff=(1, 0.5))
    return g.point(lambda v: int(255 * (v / 255) ** 1.6))
def crop(p, x0, y0, x1, y1, tag):
    im = Image.open(base + 'orig/p-%03d.png' % p).convert('L')
    c = enhance(im.crop((x0, y0, x1, y1)).resize((int((x1 - x0) * SC), int((y1 - y0) * SC)), Image.LANCZOS))
    W, H = c.size
    o = Image.new('RGB', (W + 2 * M, H + 2 * M), 'white'); o.paste(c.convert('RGB'), (M, M))
    d = ImageDraw.Draw(o)
    for x in range((x0 // 25 + 1) * 25, x1, 25):
        X = M + (x - x0) * SC; big = x % 100 == 0
        for yy in (0, H + M):
            d.line([(X, yy + (M - (14 if big else 7)) if yy == 0 else yy), (X, yy + (M if yy == 0 else (14 if big else 7)))], fill=(220, 0, 0), width=2 if big else 1)
        if big: d.text((X + 3, 2), str(x), fill=(200, 0, 0)); d.text((X + 3, H + M + 18), str(x), fill=(200, 0, 0))
    for y in range((y0 // 25 + 1) * 25, y1, 25):
        Y = M + (y - y0) * SC; big = y % 100 == 0
        d.line([(M - (14 if big else 7), Y), (M, Y)], fill=(0, 0, 220), width=2 if big else 1)
        d.line([(W + M, Y), (W + M + (14 if big else 7), Y)], fill=(0, 0, 220), width=2 if big else 1)
        if big: d.text((1, Y + 3), str(y), fill=(0, 0, 200)); d.text((W + M + 2, Y + 3), str(y), fill=(0, 0, 200))
    out = base + 'view/p%03d_%s.png' % (p, tag); o.save(out); return out
for a in sys.argv[1:]:
    p = int(a)
    print(crop(p, 30, 40, 790, 580, 'a')); print(crop(p, 30, 560, 790, 1090, 'b'))
