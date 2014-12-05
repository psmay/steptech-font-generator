#!/usr/bin/env python

import datetime
import fontforge
import json
import os
import sys
import shutil
import tempfile

def generate_font_project_file(meta, outfile):
    font = fontforge.font()
    font.fontname = "STDevGen-1stMix-%s" % datetime.datetime.utcnow().isoformat()
    for em in meta:
        codepoint = em["loose"]["codepoint"]
        basename = em["file_basename"]
        width = em["loose"]["width"]

        glyph = font.createChar(codepoint)
        glyph.importOutlines(tight_svg_filename(basename))
        glyph.width = width
        glyph.simplify()
    font.save(outfile)

def tight_svg_filename(basename):
    return os.path.join("tight-shapes", basename + ".svg")

def cat(filename):
    f = open(filename, "rb")
    try:
        shutil.copyfileobj(f, sys.stdout)
    finally:
        f.close()

def with_temp_dir(fn):
    temp_dir = tempfile.mkdtemp()
    try:
        return fn(temp_dir)
    finally:
        shutil.rmtree(temp_dir)

def generate_font_project_stdio_via_temp(temp_dir):
    meta = json.load(sys.stdin)
    outfile = os.path.join(temp_dir, "out.sfd")
    generate_font_project_file(meta, outfile)
    cat(outfile)

with_temp_dir(generate_font_project_stdio_via_temp)

