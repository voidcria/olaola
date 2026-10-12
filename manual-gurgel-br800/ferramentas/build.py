# Monta o manual redigido: txt/pNNN.md -> out/manual.html (+ recortes tratados em out/img)
import sys, re, os, glob, subprocess, html
import numpy as np, cv2
from PIL import Image
sys.path.insert(0, os.path.dirname(__file__))
import enh

B = '/tmp/claude-0/-home-user-olaola/506d9357-0233-5e61-ba9a-2093b0ac2642/scratchpad/'
COLW, FULLW = 310.0, 640.0   # largura (px nativos) de uma coluna / da área útil no original
only = set(int(a) for a in sys.argv[1:]) if len(sys.argv) > 1 else None

def make_img(p, k, box, orig, rot):
    name = 'img/p%03d_%d.jpg' % (p, k)
    dst = B + 'out/' + name
    src = B + 'orig/p-%03d.png' % p
    key = (box, orig, rot)
    stamp = dst + '.key'
    if os.path.exists(dst) and os.path.exists(stamp) and open(stamp).read() == repr(key) \
            and os.path.getmtime(dst) > os.path.getmtime(B + 'tools/enh.py'):
        return name
    a = enh.load(p, box)
    out = a if orig else enh.enhance(a)
    if rot: out = np.ascontiguousarray(np.rot90(out, k=rot // 90))
    Image.fromarray(out).save(dst, quality=85, optimize=True)
    open(stamp, 'w').write(repr(key))
    return name

def fig_html(p, k, spec):
    left, _, cap = spec.partition('|')
    parts = left.split()
    bs = parts[0]
    if bs[:2] in ('a:', 'b:'):   # coordenadas de tela das vistas v2.py (metade a/b)
        y0 = 40 if bs[0] == 'a' else 560
        X0, Y0, X1, Y1 = (float(v) for v in bs[2:].split(','))
        box = (max(0, int((X0 - 34) / 1.9 + 30) - 3), max(0, int((Y0 - 34) / 1.9 + y0) - 3),
               min(794, int((X1 - 34) / 1.9 + 30) + 3), min(1122, int((Y1 - 34) / 1.9 + y0) + 3))
    else:
        box = tuple(int(v) for v in bs.split(','))
    opts = parts[1:]
    wide = 'wide' in opts; orig = 'orig' in opts
    rot = next((int(o[4:]) for o in opts if o.startswith('rot=')), 0)
    w = next((float(o[2:]) for o in opts if o.startswith('w=')), None)
    bw = box[2] - box[0] if rot in (0, 180) else box[3] - box[1]
    if w is None:
        w = min(100.0, 100.0 * bw / (FULLW if wide else COLW))
    name = make_img(p, k, box, orig, rot)
    cls = 'fig' + (' wide' if wide else '') + ''.join(' ' + o for o in opts if o in ('left', 'right', 'inline'))
    cap = cap.strip()
    caphtml = '<figcaption>%s</figcaption>' % cap if cap else ''
    return '<figure class="%s" style="width:%.0f%%"><img src="%s" alt="">%s</figure>' % (cls, w, name, caphtml)

pages = sorted(glob.glob(B + 'txt/p*.md'))
md = []
for f in pages:
    p = int(re.search(r'p(\d+)\.md$', f).group(1))
    if only and p not in only: continue
    classes, num, body, k = [], None, [], 0
    raw = open(f, encoding='utf-8').read().split('\n')
    # linhas de continuação dentro de itens de lista (ex.: "a) ...") recebem recuo,
    # senão o pandoc as funde com os itens seguintes
    fixed, in_item = [], False
    for ln in raw:
        if re.match(r'\d+\. |- |\\- ', ln):
            in_item = not ln.startswith('\\')
        elif not ln.strip() or ln.startswith(('%', '#', '<', '|')):
            in_item = in_item and bool(ln.strip()) is False and False
        elif in_item and fixed and fixed[-1].strip():
            ln = '    ' + ln
        fixed.append(ln)
    for line in fixed:
        if line.startswith('%class '): classes += line[7:].split()
        elif line.startswith('%cols '): classes.append('cols' + line[6:].strip())
        elif line.startswith('%num '): num = line[5:].strip()
        elif line.startswith('%fig '):
            k += 1; body += ['', fig_html(p, k, line[5:]), '']
        elif re.match(r'%L\d? ', line):
            m = re.match(r'%L(\d?) (.*?)(?: :: (.*))?$', line)
            lvl, lab, val = m.group(1) or '0', m.group(2), m.group(3) or ''
            if m.group(3) is None:
                body.append('<div class="lead ind%s"><span class="l">%s</span></div>' % (lvl, lab))
            else:
                body.append('<div class="lead ind%s"><span class="l">%s</span><span class="d"></span><span class="r">%s</span></div>' % (lvl, lab, val))
        elif line.startswith('%TH '):   # cabeçalho de tabela de torques: %TH título :: Nm :: mkgf
            parts = [x.strip() for x in line[4:].split('::')]
            body.append('<div class="tq tqh"><span class="l"><strong>%s</strong></span><span class="v">%s</span><span class="v">%s</span></div>' % tuple(parts + [''] * (3 - len(parts))))
        elif line.startswith('%T '):    # linha de torque: %T descrição :: Nm :: mkgf
            parts = [x.strip() for x in line[3:].split('::')]
            body.append('<div class="tq"><span class="l">%s</span><span class="d"></span><span class="v">%s</span><span class="v">%s</span></div>' % tuple(parts + [''] * (3 - len(parts))))
        elif line.strip() == '%colbreak': body += ['', '<div class="colbreak"></div>', '']
        elif line.strip() == '%span': body += ['', '::: span', '']
        elif line.strip() == '%endspan': body += ['', ':::', '']
        else: body.append(line)
    # blocos HTML brutos (tabelas, svg) passam intactos pelo pandoc
    out, i = [], 0
    while i < len(body):
        ln = body[i]
        m = re.match(r'\s*<(table|svg|div class="(?:toc|diagwrap)[^"]*")', ln)
        if m:
            tag = m.group(1).split()[0]
            blk = [ln]
            depth = ln.count('<' + tag) - ln.count('</' + tag)
            while depth > 0 and i + 1 < len(body):
                i += 1; blk.append(body[i]); depth += body[i].count('<' + tag) - body[i].count('</' + tag)
            out += ['', '```{=html}'] + blk + ['```', '']
        else:
            out.append(ln)
        i += 1
    body = out
    md.append('\n:::::: {.pg %s data-p="%d"}\n\n::::: body\n\n%s\n\n:::::\n\n<div class="pgnum">%s</div>\n\n::::::\n'
              % (' '.join('.' + c for c in classes), p, '\n'.join(body), num or ''))

src = '\n'.join(md)
open(B + 'out/debug.md', 'w').write(src)
r = subprocess.run(['pandoc', '-f', 'markdown-auto_identifiers-pandoc_title_block-fancy_lists+pipe_tables+grid_tables', '-t', 'html5'],
                   input=src.encode(), capture_output=True)
if r.returncode: print(r.stderr.decode()); sys.exit(1)
bodyhtml = r.stdout.decode()
tpl = open(B + 'tools/template.html', encoding='utf-8').read()
open(B + 'out/manual.html', 'w', encoding='utf-8').write(tpl.replace('<!--BODY-->', bodyhtml))
print('ok', len(md), 'páginas')
