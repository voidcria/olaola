# Tabelas "Falhas / Causa Provável"
def table(rows, h1='Falhas', h2='Causa Provável', w1=27):
    o = ['<table class="grid falhas"><colgroup><col style="width:%d%%"><col></colgroup>' % w1,
         '<thead><tr><th style="text-align:left">%s</th><th>%s</th></tr></thead><tbody>' % (h1, h2)]
    for f, c in rows:
        cs = c if isinstance(c, list) else [c]
        o.append('<tr><td>%s</td><td>%s</td></tr>' % (f, ''.join('<p>%s</p>' % x for x in cs)))
    o.append('</tbody></table>')
    return '\n'.join(o)

def table3(rows, h=('Falha', 'Causa Provável', 'Correção'), w=(26, 37)):
    # rows: (falha, [(causa, correção), ...])
    o = ['<table class="grid falhas f3"><colgroup><col style="width:%d%%"><col style="width:%d%%"><col></colgroup>' % w,
         '<thead><tr>%s</tr></thead><tbody>' % ''.join('<th>%s</th>' % x for x in h)]
    for f, pairs in rows:
        o.append('<tr><td>%s</td><td>%s</td><td>%s</td></tr>' % (
            f, ''.join('<p>. %s</p>' % c for c, _ in pairs), ''.join('<p>. %s</p>' % r for _, r in pairs)))
    o.append('</tbody></table>')
    return '\n'.join(o)
