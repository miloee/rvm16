#!/usr/bin/env python3
from PIL import Image, ImageDraw, ImageFont
import os

OUT = os.path.dirname(os.path.abspath(__file__))
FONT = 'C:/Windows/Fonts/msyh.ttc'
BOLD = 'C:/Windows/Fonts/msyhbd.ttc'
NL = chr(10)


def f(sz, bold=False):
    return ImageFont.truetype(BOLD if bold else FONT, sz)


def rounded(d, box, r, fill, outline=None, width=2):
    d.rounded_rectangle(box, radius=r, fill=fill, outline=outline, width=width)


# block map
W, H = 1280, 900
img = Image.new('RGB', (W, H), 'white')
d = ImageDraw.Draw(img)
d.text((40, 28), 'RVM16-C：quadrant 11 的 16 个 f4 block', font=f(34, True), fill='#111')
d.text((40, 78), 'RVC 的 quadrant 00/01/10 保持不变；每条指令 16 位', font=f(20), fill='#555')

blocks = [
    ('0', 'ALU-12 A', 'add / sub' + NL + 'and / or', '#dbeafe'),
    ('1', 'ALU-12 B', 'xor / sll' + NL + 'srl / sra', '#dbeafe'),
    ('2', 'ALU-12 C', 'slt / sltu' + NL + '(2 reserved)', '#dbeafe'),
    ('3', 'GP / PC', 'lwgp / swgp' + NL + 'lwpc', '#dcfce7'),
    ('4', 'M', 'mulh / div' + NL + 'rem', '#fef3c7'),
    ('5', 'c.bne', '融合分支' + NL + 'off4 ±16B', '#fee2e2'),
    ('6', 'c.blt', '融合分支' + NL + 'off4 ±16B', '#fee2e2'),
    ('7', 'c.blez', '融合分支' + NL + 'off7 ±128B', '#fee2e2'),
    ('8', 'LD / ST', 'lwc / swc' + NL + '4 base', '#e0e7ff'),
    ('9', 'F32 A', 'fadd/fsub' + NL + 'fmul/fdiv', '#fce7f3'),
    ('10', 'F32 B', 'fsqrt/fmin' + NL + 'fmax/fsgnj', '#fce7f3'),
    ('11', 'F32 C', 'fsgnjn/fsgnjx' + NL + 'feq/flt', '#fce7f3'),
    ('12', 'F32 D', 'fle/fcvt' + NL + 'fclass', '#fce7f3'),
    ('13', 'F32 E', 'fmv/flw/fsw', '#fce7f3'),
    ('14', 'CSR', 'csrr/csrw' + NL + 'csrs/csrc', '#ede9fe'),
    ('15', 'SYS', 'ecall/mret' + NL + 'wfi/fence', '#e5e7eb'),
]
x0, y0 = 40, 125
cw, ch, gap = 285, 155, 12
for i, (num, name, body, color) in enumerate(blocks):
    r, c = divmod(i, 4)
    x = x0 + c * (cw + gap)
    y = y0 + r * (ch + gap)
    rounded(d, (x, y, x + cw, y + ch), 14, color, '#94a3b8', 2)
    d.text((x + 14, y + 10), 'f4=' + num, font=f(20, True), fill='#334155')
    d.text((x + 14, y + 42), name, font=f(24, True), fill='#111')
    d.multiline_text((x + 14, y + 78), body, font=f(18), fill='#334155', spacing=4)

leg = [('ALU', '#dbeafe'), ('GP/PC', '#dcfce7'), ('M', '#fef3c7'),
       ('分支', '#fee2e2'), ('LD/ST', '#e0e7ff'), ('F32', '#fce7f3'),
       ('CSR/SYS', '#ede9fe')]
lx = 40
for name, col in leg:
    rounded(d, (lx, 820, lx + 26, 846), 6, col, '#94a3b8', 1)
    d.text((lx + 34, 820), name, font=f(18), fill='#334155')
    lx += 170
img.save(os.path.join(OUT, 'rvm16c-blockmap.png'))

# code size
W, H = 1280, 720
img = Image.new('RGB', (W, H), 'white')
d = ImageDraw.Draw(img)
d.text((40, 28), 'Code size 对比：RV32EC+Zc* vs RVM16-C', font=f(34, True), fill='#111')
d.text((40, 78), 'FIR/sum 为实测；Dhrystone/CoreMark 为静态模型', font=f(20), fill='#555')


def panel(x, y, w, h, title, data, ymax, step):
    d.text((x, y), title, font=f(22, True), fill='#111')
    top, bottom = y + 45, y + h
    left, right = x + 60, x + w
    d.line((left, top, left, bottom), fill='#94a3b8', width=2)
    d.line((left, bottom, right, bottom), fill='#94a3b8', width=2)
    for v in range(0, ymax + 1, step):
        yy = bottom - (v / ymax) * (bottom - top)
        d.line((left - 6, yy, left, yy), fill='#94a3b8', width=2)
        d.text((x, yy - 10), str(v), font=f(15), fill='#64748b')
    n = len(data)
    group = (right - left) / n
    bw = group * 0.26
    for i, (name, a, b) in enumerate(data):
        cx = left + group * (i + 0.5)
        ha = (a / ymax) * (bottom - top)
        hb = (b / ymax) * (bottom - top)
        d.rectangle((cx - bw - 4, bottom - ha, cx - 4, bottom), fill='#94a3b8')
        d.rectangle((cx + 4, bottom - hb, cx + bw + 4, bottom), fill='#2563eb')
        d.text((cx - bw - 4, bottom - ha - 24), str(a), font=f(16, True), fill='#475569')
        d.text((cx + 4, bottom - hb - 24), str(b), font=f(16, True), fill='#1d4ed8')
        bb = d.textbbox((0, 0), name, font=f(18))
        d.text((cx - (bb[2] - bb[0]) / 2, bottom + 8), name, font=f(18), fill='#111')


panel(40, 120, 560, 470, '小内核（B）', [('FIR', 30, 26), ('sum', 24, 20)], 36, 6)
panel(660, 120, 580, 470, 'Dhrystone / CoreMark（B）',
      [('Dhrystone', 2508, 1906), ('CoreMark', 6398, 6316)], 7200, 1200)
rounded(d, (40, 640, 66, 666), 6, '#94a3b8')
d.text((76, 638), 'RV32EC+Zc*', font=f(18), fill='#334155')
rounded(d, (230, 640, 256, 666), 6, '#2563eb')
d.text((266, 638), 'RVM16-C', font=f(18), fill='#1d4ed8')
d.text((420, 638), 'Dhrystone -24% / CoreMark -1.3%', font=f(18), fill='#334155')
img.save(os.path.join(OUT, 'rvm16c-codesize.png'))
print('figures written')
