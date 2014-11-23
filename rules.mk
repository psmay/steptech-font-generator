
JSON_ALL=elements-all.json
# The direct result of splitting JSON_ALL
ELEMENTS_TEMP=.tmp.elements
# A clone of the above with timestamps reflecting only actual changes
ELEMENTS=elements
# Discorporate SVG files containing individual pseudo-stroke shapes
LOOSE_SHAPES=loose-shapes
# SVG files with loose shapes unioned together
TIGHT_SHAPES=tight-shapes
TIGHT_SHAPES_TEMP=.tmp.tight-shapes

DEFINE_ELEMENT_FILES=element-files.dep

all: tight

$(ELEMENTS): $(JSON_ALL)
	rm -rf $(ELEMENTS_TEMP)
	mkdir -p $(ELEMENTS_TEMP)
	../split-char-data.pl $(ELEMENTS_TEMP) $^
	@# Update only the changed elements to prevent spurious rebuilds.
	@# (rsync by checksum instead of time.)
	@# (-rlpgoD instead of -a: We don't want to update times on unchanged files.)
	rsync -rlpgoD --delete --checksum $(ELEMENTS_TEMP)/ $@/
	rm -rf $(ELEMENTS_TEMP)

# Generate a makefile include for the element file list
$(DEFINE_ELEMENT_FILES): $(ELEMENTS)
	+@echo -n "ELEMENT_FILES =" > $@
	+@find $< -type f -name '*.json' -print0 | sort -z | xargs -0 -i echo -n " {}" >> $@
	+@echo "" >> $@

-include $(DEFINE_ELEMENT_FILES)

LOOSE_SHAPE_FILES=$(ELEMENT_FILES:$(ELEMENTS)/%.json=$(LOOSE_SHAPES)/%.svg)
TIGHT_SHAPE_FILES=$(ELEMENT_FILES:$(ELEMENTS)/%.json=$(TIGHT_SHAPES)/%.svg)

# Prevent auto-delete of intermediates
.SECONDARY: $(ELEMENT_FILES) $(LOOSE_SHAPE_FILES) $(TIGHT_SHAPE_FILES)

tight: $(TIGHT_SHAPE_FILES)

loose: $(LOOSE_SHAPE_FILES)

$(ELEMENT_FILES): | $(ELEMENTS)

$(LOOSE_SHAPES):
	+@[ -d $@ ] || mkdir -p $@

$(TIGHT_SHAPES):
	+@[ -d $@ ] || mkdir -p $@

$(TIGHT_SHAPES_TEMP):
	+@[ -d $@ ] || mkdir -p $@

$(LOOSE_SHAPES)/%.svg: $(ELEMENTS)/%.json ../element-to-loose-svg.pl | $(LOOSE_SHAPES)
	../element-to-loose-svg.pl < $< > $@

$(TIGHT_SHAPES)/%.svg: $(LOOSE_SHAPES)/%.svg | $(TIGHT_SHAPES) $(TIGHT_SHAPES_TEMP)
	@$(eval ENTRE := $(TIGHT_SHAPES_TEMP)/$(notdir $@))
	cp $^ $(ENTRE)
	inkscape --verb EditSelectAllInAllLayers --verb SelectionUnion --verb FileSave --verb FileClose $(ENTRE)
	scour -i $(ENTRE) -o $@

