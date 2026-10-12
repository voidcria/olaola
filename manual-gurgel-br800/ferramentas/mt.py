# Gera as tabelas de manutenção (páginas 0.01.x)
COLS = ['E', '1', '7', '15', '30', '45', '90']
HEAD = ('<table class="grid mt"><colgroup><col style="width:34%">' + '<col>' * 7 + '</colgroup>'
        '<thead><tr><th>OPERAÇÕES</th><th>revisão<br>de<br>entrega</th><th>1.000<br><br>Km</th>'
        '<th>7500<br>22500<br>37500<br>52500<br>67500<br>82500<br>97500<br>Km</th>'
        '<th>15000<br>75000<br><br>Km</th><th>30000<br>60000<br><br>km</th><th>45000<br><br>Km</th><th>90000<br><br>Km</th></tr></thead><tbody>')
def table(sections, foot=''):
    o = [HEAD]
    for title, sub, rows in sections:
        if title:
            o.append('<tr class="mtsec"><td colspan="8"><strong>%s</strong>%s</td></tr>' % (title, ('<br>' + sub) if sub else ''))
        for text, marks in rows:
            m = dict()
            for tok in marks.split():
                if tok.endswith('+'): m[tok[:-1]] = '+'
                else: m[tok] = '•'
            o.append('<tr><td>· %s</td>%s</tr>' % (text, ''.join('<td class="c">%s</td>' % m.get(c, '') for c in COLS)))
    o.append('</tbody></table>')
    if foot: o.append('<p class="small">%s</p>' % foot.replace('+', '&#43;'))
    return '\n'.join(o)
