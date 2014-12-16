StepTech font generator
=======================

![StepTech 1stMix font sample](http://psmay.github.io/steptech-font-generator/images/StepTech-1stMix-sample.png)

This is a suite of scripts used to convert JSON-based descriptions of glyphs for the StepTech typeface into SVG files and then into a FontForge project.

What this does
--------------

Currently, the steps involved are these:

*   The information in the master JSON glyphs file, `elements-all.json`, is split up into individual JSON glyph files, one per glyph.
*   Each JSON glyph description consists of a number of directed line segments.
    *   Each segment can have a `guide_color` property. This does not impact the final product but can be helpful when editing the description.
    *   Each segment can have a `draw` property which is set to `true` (default) or `false`. If set to `false`, the segment is never actually drawn, but the bounding box for the glyph is calculated as if it were.
        *   This is used for space-only glyphs (as done with space (U+0020)) or to artificially extend the width of a narrow glyph (as done with `1` to make its width match that of the other digits).
    *   Each segment has two endpoints, `from` and `to`.
        *   Each endpoint has an `x` and a `y`, which are defined as a number of pixels right and down, respectively, from the base point.
        *   Each endpoint has a `cap` which describes the end cap for that endpoint.
            *   `none` indicates no cap; the stroke ends at the endpoint, cut perpendicular to the segment.
            *   `shear` indicates no cap; the stroke is cut diagonally to that the stroke edge counterclockwise from the endpoint is `S` farther out than the endpoint, while the stroke edge clockwise from the endpoint is `S` behind the endpoint, where `S` is the value of a separate `shear` property multiplied by the stroke width.
                *   If a stroke is viewed as vertical, and it is observed that `+y` is the downward direction, the `shear` value is the slope of the cut.
                *   If the `shear` value is 0, the `shear` cap is equivalent to the `none` cap.
            *   `s` indicates a square cap; the stroke extends past the endpoint by half the stroke width before being cut perpendicular to the segment.
                *   The effect is the same as extending this end of the segment by half the stroke width, then specifying a `cap` of `none`.
            *   `c` indicates a circular arc with a diameter the same as the stroke width.
            *   `sc` indicates a cap that is like `s` its counterclockwise half and like `c` on its clockwise half.
            *   `cs` indicates a cap that is like `c` its counterclockwise half and like `s` on its clockwise half.
            *   `in` (default for `from` endpoint) and `out` (default for `to` endpoint) indicate placeholder caps (the tail and head ends of an arrow) to help determine the orientation of segments not yet manually edited.
        *   An endpoint may have a `dotdir` value of `x`, `y`, or a number of degrees that will be used to determine the orientation of a segment having zero length.
            *   If the segment length is nonzero, the orientation is determined by the relative positions of the endpoints and `dotdir` is ignored.
*   Each JSON glyph file is converted to a simple "loose shapes" SVG file using `element-to-loose-svg.pl`.
    *   The result of this step is used to determine what modifications should be made to the master JSON.
    *   This is where `guide_color` appears.
    *   The "segments" from the description are rendered here as paths, not strokes, to accommodate the various end caps more easily.
    *   This script hardcodes some parameters of the font.
        *   The page height is 1000 pixels.
        *   The horizontal baseline 800 pixels from the top (200 pixels from the bottom).
        *   The vertical baseline is 0.
        *   The stroke width is 100 pixels.
    *   The generated loose shapes SVG contains a small amount of JSON metadata containing values produced in the drawing process, such as the advance width for the glyph.
*   Each loose shapes SVG has its contents unioned together via `inkscape` into an SVG containing a single "unioned shape" path.
    *   This step takes the bulk of the processing time. `inkscape` is started and exited for each file processed. (If you know of a way this can be batched more efficiently, I'm listening.)
*   Each unioned shapes SVG has its contents sanitized via `scour` into a "tight shape" SVG suitable for import into FontForge.
    *   Without the `scour` step, FontForge sees a triple outline on the shapes instead of the desired single outline.
*   The tight shapes (with information from the JSON metadata embedded in the corresponding loose shape SVGs) are dumped into a FontForge project file (`build/project.sfd`).

Requirements
------------

*   Relatively recent Perl and Python
*   Perl JSON module (Ubuntu package `libjson-perl`)
*   Inkscape (Ubuntu package `inkscape`)
*   scour (Ubuntu package `python-scour`)
*   FontForge Python bindings (Ubuntu package `python-fontforge`)

The `loose` target converts each JSON description into a "loose" SVG with one path per stroke. This target only requires the Perl JSON module.

The `unioned` target unions all of the paths in each loose SVG into a single path, resulting in a "unioned" SVG. This target requires Inkscape to union the paths.

The `tight` target sanitizes the unioned SVG output of Inkscape into a form readily consumed by FontForge. This target requires scour to remove parts of the Inkscape result too complex for FontForge to read correctly.

The `ext-meta-all` target extracts JSON metadata produced by the loose SVG generation, adds other related data, and produces a table of glyph metadata used later by the `fontforge-project` target. This target only requires Perl.

The `fontforge-project` target uses the tight SVG outlines and additional metadata (from `ext-meta-all`) to produce a new FontForge project file (`build/project.sfd`). This target requires Python bindings for FontForge.

`Self Intersecting` Validation failure
--------------------------------------

Currently, attempting to generate an OpenType font from the FontForget project results in Self Intersecting errors for several glyphs (more if the simplify step is omitted from the export script). I would love to get this fixed properly, especially since there is no apparent actual self-intersection going on. In the meantime, though, it is possible to ignore these warnings and generate the font anyway, and in all my testing so far these issues are not manifested by any actual problems.

PCB
---

The glyphs for this font were given their initial rough outlines in gEDA PCB. While that program is for circuit board design and not for graphics, per se, it has over Inkscape the ability to preserve extremely precise position information without complicated transformations, and its file format is simple enough for extraction using Perl.

That's where `pcb-to-elements.pl` comes in. This script pulls information out of a PCB file, with the following expectations:

*   The PCB format hasn't changed substantially from the version the script was designed around.
*   Each element is a glyph.
*   Each element's name is the glyph's name. (See Adobe Glyph List for New Fonts (AGLFN) for appropriate values.)
*   Each element consists only of `Pad` lines (others will be skipped).
*   Each element originates at the baselines.
*   All pad endpoint coordinates are in `mil` or in the base unit (0.01 mil).
    *   Figures in `mm` will be misread.
*   1 mil means 1 pixel.

Additionally, the trace width should be 100 mil (i.e. whatever `element-to-loose-svg.pl` expects, in mil instead of pixels).

PCB can't by itself encode the `none`, `shear`, `sc`, and `cs` endcaps I needed, so that information is added manually to the master JSON. Currently, the `square` flag on a pad will not be encoded as having a square cap, though perhaps it should.

My original PCB file is not included here because `elements-all.json` contains all of the same information *plus* the end cap data, dotdirs, and a few other bits; it's effectively the source, and the PCB file is not.

License
-------

### StepTech font description

The StepTech font description consists of the following file in this distribution:

    elements-all.json

The StepTech font description is provided under the terms of the GNU General Public License (see notice below).

#### No font exception

These terms **do not include a font exception.** This means, for example, that documents embedding all or part of a font based on this description or artwork featuring such a font may qualify as a derivative work (and therefore may be subject to the same terms).

This may change in the future as I familiarize myself with the limitations of other free software font licenses.

I reserve the right to make this software available to other parties under alternate terms without offering the same to the public at large.

#### GNU General Public License (notice)

StepTech font description

Copyright © 2014 Peter S. May

This program is free software: you can redistribute it and/or modify it under the terms of the GNU General Public License as published by the Free Software Foundation, either version 3 of the License, or (at your option) any later version.

This program is distributed in the hope that it will be useful, but WITHOUT ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the GNU General Public License for more details.

You should have received a copy of the GNU General Public License along with this program. If not, see <http://www.gnu.org/licenses/>.

### StepTech font generator

The StepTech font generator consists of the following files in this distribution:

    ComposeRunner.pm
    element-to-loose-svg.pl
    generate-font-project.py
    json-files-to-array.sh
    Makefile
    pcb-to-elements-data.pl
    reformat-master.pl
    rules.mk
    split-char-data.pl

The StepTech font generator is provided under the terms of the OSI-approved MIT License (see terms below).

#### The MIT License

Copyright © 2014 Peter S. May

Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated documentation files (the "Software"), to deal in the Software without restriction, including without limitation the rights to use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of the Software, and to permit persons to whom the Software is furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
