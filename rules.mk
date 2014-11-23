
JSON_ALL=elements-all.json
# The direct result of splitting JSON_ALL
JSON_FRESH_SPLIT_ELEMENTS=.tmp.json-split-elements
# A clone of the above with timestamps reflecting only actual changes
JSON_SPLIT_ELEMENTS=json-split-elements
# Discorporate SVG files containing individual pseudo-stroke shapes
LOOSE_SHAPES=loose-shapes
# SVG files with loose shapes unioned together
TIGHT_SHAPES=tight-shapes
TIGHT_SHAPES_TMP=.tmp.tight-shapes

DEFINE_FRESH_SPLIT_ELEMENT_FILES=elements-list.dep

include $(DEFINE_FRESH_SPLIT_ELEMENT_FILES)
SPLIT_ELEMENT_FILES=$(FRESH_SPLIT_ELEMENT_FILES:$(JSON_FRESH_SPLIT_ELEMENTS)/%.json=$(JSON_SPLIT_ELEMENTS)/%.json)
LOOSE_SHAPE_FILES=$(SPLIT_ELEMENT_FILES:$(JSON_SPLIT_ELEMENTS)/%.json=$(LOOSE_SHAPES)/%.svg)
TIGHT_SHAPE_FILES=$(LOOSE_SHAPE_FILES:$(LOOSE_SHAPES)/%.svg=$(TIGHT_SHAPES)/%.svg)

all: $(TIGHT_SHAPE_FILES)

# Prevent auto-delete of intermediates
.SECONDARY: $(SPLIT_ELEMENT_FILES) $(LOOSE_SHAPE_FILES) $(TIGHT_SHAPE_FILES)

$(JSON_FRESH_SPLIT_ELEMENTS): $(JSON_ALL)
	rm -rf $(JSON_FRESH_SPLIT_ELEMENTS)
	mkdir -p $(JSON_FRESH_SPLIT_ELEMENTS)
	@# Get splits of character data into the temp dir.
	@# This is a very inexpensive operation, so it's okay to repeat it as often as needed.
	../split-char-data.pl $(JSON_FRESH_SPLIT_ELEMENTS) $^

# Determine the actual target filenames based on the split output.
$(DEFINE_FRESH_SPLIT_ELEMENT_FILES): $(JSON_FRESH_SPLIT_ELEMENTS)
	+@echo -n "FRESH_SPLIT_ELEMENT_FILES =" > $@
	+@find $< -type f -name '*.json' -print0 | sort -z | xargs -0 -i echo -n " {}" >> $@
	+@echo "" >> $@

$(JSON_SPLIT_ELEMENTS): $(JSON_FRESH_SPLIT_ELEMENTS)
	@# Update only the changed elements to prevent spurious rebuilds.
	@# (rsync by checksum instead of time.)
	@# (-rlpgoD instead of -a: We don't want to update times on unchanged files.)
	rsync -rlpgoDv --delete --checksum $</ $@/

$(SPLIT_ELEMENT_FILES): $(JSON_SPLIT_ELEMENTS)

$(LOOSE_SHAPES):
	+@[ -d $@ ] || mkdir -p $@

$(TIGHT_SHAPES):
	+@[ -d $@ ] || mkdir -p $@

$(TIGHT_SHAPES_TMP):
	+@[ -d $@ ] || mkdir -p $@


$(LOOSE_SHAPES)/%.svg: $(JSON_SPLIT_ELEMENTS)/%.json | $(LOOSE_SHAPES)
	../element-to-loose-svg.pl < $^ > $@

$(TIGHT_SHAPES)/%.svg: $(LOOSE_SHAPES)/%.svg | $(TIGHT_SHAPES) $(TIGHT_SHAPES_TMP)
	@$(eval ENTRE := $(TIGHT_SHAPES_TMP)/$(notdir $@))
	cp $^ $(ENTRE)
	inkscape --verb EditSelectAllInAllLayers --verb SelectionUnion --verb FileSave --verb FileClose $(ENTRE)
	scour -i $(ENTRE) -o $@

