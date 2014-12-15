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
    familyname = "STDevGen_1stMix"
    font.familyname = familyname
    font.fullname = familyname + "-Normal"
    font.fontname = familyname
    for em in meta:
        codepoint = em["loose"].get("codepoint",None)
        if codepoint is None:
            # Some of the glyphs are not intended as actual characters.
            continue

        basename = em["file_basename"]
        width = em["loose"].get("width",0)
        lines = em["loose"].get("lines",[])

        glyph = font.createChar(codepoint)

        # Reportedly, importOutlines() doesn't like importing files without
        # any paths. If there are none, we can just skip it anyway.
        draw = False
        for line in lines:
            draw = bool(line.get("draw", True))
            if draw:
                break

        if draw:
            glyph.importOutlines(tight_svg_filename(basename))
        else:
            print >> sys.stderr, "Note: %s rendered as spacing-only" % codepoint

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

