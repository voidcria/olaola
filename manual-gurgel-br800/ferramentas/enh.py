# Tratamento de figuras: recorte da página original, ampliação 2x, redução de ruído,
# ajuste de níveis (fundo branco / pretos profundos) e nitidez.
import sys, cv2, numpy as np
from PIL import Image
base = '/tmp/claude-0/-home-user-olaola/506d9357-0233-5e61-ba9a-2093b0ac2642/scratchpad/'

def load(p, box):
    im = Image.open(base + 'orig/p-%03d.png' % p).convert('L').crop(box)
    return np.array(im)

def levels(a, lo_pct=0.5, hi_pct=99.0, gamma=1.0):
    lo, hi = np.percentile(a, lo_pct), np.percentile(a, hi_pct)
    if hi - lo < 10: return a
    b = np.clip((a.astype(np.float32) - lo) / (hi - lo), 0, 1) ** gamma
    return (b * 255).astype(np.uint8)

def enhance(a, scale=2, h=9, sharp=0.8, gamma=1.15):
    a = cv2.fastNlMeansDenoising(a, None, h=h, templateWindowSize=7, searchWindowSize=21)
    a = cv2.resize(a, None, fx=scale, fy=scale, interpolation=cv2.INTER_LANCZOS4)
    a = levels(a, 0.3, 99.5, gamma)
    blur = cv2.GaussianBlur(a, (0, 0), 1.6)
    a = cv2.addWeighted(a, 1 + sharp, blur, -sharp, 0)
    return a

if __name__ == '__main__':
    p = int(sys.argv[1]); box = tuple(map(int, sys.argv[2].split(',')))
    a = load(p, box)
    o = cv2.resize(a, None, fx=2, fy=2, interpolation=cv2.INTER_NEAREST)
    e = enhance(a)
    cv2.imwrite(base + 'view/enh_orig.png', o); cv2.imwrite(base + 'view/enh_new.png', e)
    both = np.hstack([o, np.full((o.shape[0], 10), 128, np.uint8), e])
    cv2.imwrite(base + 'view/enh_cmp.png', both)
    print(a.shape)
