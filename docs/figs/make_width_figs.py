#!/usr/bin/env python3
from PIL import Image, ImageDraw, ImageFont
import os

OUT = os.path.dirname(os.path.abspath(__file__))
FONT = 'C:/Windows/Fonts/msyh.ttc'
BOLD = 'C:/Windows/Fonts/msyhbd.ttc'


def f(sz, bold=False):
    return ImageFont.truetype(BOLD if bold else FONT, sz)


def rounded(d, box, r, fill, outline=None, width=2):
    d.rounded_rectangle(box, radius=r, fill=fill, outline=outline, width=width)


# 1. instruction width comparison
W, H = 1280, 640
img = Image.new('RGB', (W, H), 'white')
d = ImageDraw.Draw(img)
d.text((40, 28), '四种指令集：指令宽度对比', font=f(36, True), fill='#111')
d.text((40, 80), '横条每一格代表一条指令，宽度对应字节数', font=f(20), fill='#555')

rows = [
    ('x86', '1–15 B 变长', '#94a3b8', [14, 30, 8, 44, 20, 36, 12, 26, 50, 18, 32, 10, 40, 24, 16, 48, 22, 34]),
    ('ARM Thumb-2', '16 + 32 位', '#f59e0b', [16, 32, 16, 16, 32, 16, 32, 16, 16, 32, 16, 32, 16, 16, 32, 16]),
    ('RISC-V RVC', '16 + 32 位', '#10b981', [16, 16, 32, 16, 16, 32, 16, 16, 16, 32, 16, 16, 32, 16, 16, 16]),
    ('RVM16-C', '只有 16 位', '#2563eb', [16] * 24),
]
bar_x, bar_w = 300, 900
for i, (name, note, color, widths) in enumerate(rows):
    y = 140 + i * 115
    d.text((40, y + 20), name, font=f(24, True), fill='#111')
    d.text((40, y + 54), note, font=f(18), fill='#555')
    x = bar_x
    for w in widths:
        ww = w * 2
        if x + ww > bar_x + bar_w:
            break
        d.rectangle((x, y + 18, x + ww, y + 78), fill=color if w == 16 else '#cbd5e1')
        x += ww + 4

rounded(d, (40, 590, 66, 616), 6, '#2563eb')
d.text((76, 588), '16 位', font=f(18), fill='#334155')
rounded(d, (160, 590, 186, 616), 6, '#cbd5e1')
d.text((196, 588), '32 位 / 更长', font=f(18), fill='#334155')
img.save(os.path.join(OUT, 'rvm16c-widths.png'))

# 2. 16-bit budget
W, H = 1280, 420
img = Image.new('RGB', (W, H), 'white')
d = ImageDraw.Draw(img)
d.text((40, 28), '16 位怎么分：两地址 ALU 的例子', font=f(34, True), fill='#111')
d.text((40, 76), 'quadrant 11 固定占 2 位；剩下 14 位要放下 f4、funct、rd、rs2', font=f(19), fill='#555')

x, y, h = 60, 150, 96
parts = [
    ('11', 2, '#111827', 'quadrant'),
    ('f4', 4, '#2563eb', 'f4'),
    ('funct2', 2, '#f59e0b', 'funct2'),
    ('rd', 4, '#10b981', 'rd'),
    ('rs2', 4, '#8b5cf6', 'rs2'),
]
total = sum(p[1] for p in parts)
for label, bits, color, name in parts:
    w = int(1160 * bits / total)
    d.rectangle((x, y, x + w, y + h), fill=color)
    d.text((x + 8, y + 10), label, font=f(20, True), fill='white')
    d.text((x + 8, y + 62), str(bits) + ' bit', font=f(16), fill='white')
    x += w

d.text((60, 290), '2 + 4 + 2 + 4 + 4 = 16 位。16 个 GPR 时，rd/rs2 各 4 位，刚好放得下。', font=f(20), fill='#334155')
d.text((60, 330), '如果 GPR 是 32 个，rd/rs2 各要 5 位，funct 就没有空间了。', font=f(20), fill='#b91c1c')
img.save(os.path.join(OUT, 'rvm16c-budget.png'))
print('figures written')
