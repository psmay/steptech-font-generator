
JSON_ALL=elements-all.json
# The direct result of splitting JSON_ALL
ELEMENTS_TEMP_DIR=.tmp.elements
# A clone of the above with timestamps reflecting only actual changes
ELEMENTS_DIR=elements
# Discorporate SVG files containing individual pseudo-stroke shapes
LOOSE_SHAPES_DIR=loose-shapes
# Metadata included in the loose SVGs, combined with the original elements
EXT_META_DIR=ext-meta
# SVG files with loose shapes unioned together
TIGHT_SHAPES_DIR=tight-shapes
TIGHT_SHAPES_TEMP_DIR=.tmp.tight-shapes

DEFINE_ELEMENT_FILES=element-files.dep

all: tight

$(ELEMENTS_DIR): $(JSON_ALL)
	rm -rf $(ELEMENTS_TEMP_DIR)
	mkdir -p $(ELEMENTS_TEMP_DIR)
	../split-char-data.pl $(ELEMENTS_TEMP_DIR) $^
	@# Update only the changed elements to prevent spurious rebuilds.
	@# (rsync by checksum instead of time.)
	@# (-rlpgoD instead of -a: We don't want to update times on unchanged files.)
	rsync -rlpgoD --delete --checksum $(ELEMENTS_TEMP_DIR)/ $@/
	rm -rf $(ELEMENTS_TEMP_DIR)

# Generate a makefile include for the element file list
$(DEFINE_ELEMENT_FILES): $(ELEMENTS_DIR)
	+@echo -n "ELEMENT_FILES =" > $@
	+@find $< -type f -name '*.json' -print0 | sort -z | xargs -0 -i echo -n " {}" >> $@
	+@echo "" >> $@

-include $(DEFINE_ELEMENT_FILES)

LOOSE_SHAPE_FILES=$(ELEMENT_FILES:$(ELEMENTS_DIR)/%.json=$(LOOSE_SHAPES_DIR)/%.svg)
EXT_META_FILES=$(ELEMENT_FILES:$(ELEMENTS_DIR)/%.json=$(EXT_META_DIR)/%.json)
TIGHT_SHAPE_FILES=$(ELEMENT_FILES:$(ELEMENTS_DIR)/%.json=$(TIGHT_SHAPES_DIR)/%.svg)

# Prevent auto-delete of intermediates
.SECONDARY: $(ELEMENT_FILES) $(LOOSE_SHAPE_FILES) $(TIGHT_SHAPE_FILES) $(EXT_META_FILES)

.PHONY: tight loose extract-ext-meta

tight: $(TIGHT_SHAPE_FILES)

loose: $(LOOSE_SHAPE_FILES)

extract-ext-meta: $(EXT_META_FILES)

$(ELEMENT_FILES): | $(ELEMENTS_DIR)

$(LOOSE_SHAPES_DIR):
	+@[ -d $@ ] || mkdir -p $@

$(EXT_META_DIR):
	+@[ -d $@ ] || mkdir -p $@

$(TIGHT_SHAPES_DIR):
	+@[ -d $@ ] || mkdir -p $@

$(TIGHT_SHAPES_TEMP_DIR):
	+@[ -d $@ ] || mkdir -p $@

$(LOOSE_SHAPES_DIR)/%.svg: $(ELEMENTS_DIR)/%.json ../element-to-loose-svg.pl | $(LOOSE_SHAPES_DIR)
	../element-to-loose-svg.pl < $< > $@

$(EXT_META_DIR)/%.json: $(ELEMENTS_DIR)/%.json $(LOOSE_SHAPES_DIR)/%.svg | $(EXT_META_DIR)
	echo -n '' > $@
	echo '{' >> $@
	echo $(word 2,$^) | perl -p -E 's!^.*\/(.*)\..*?$$!"file_basename":"$$1",!' >> $@
	echo '"loose":' >> $@
	perl -n -E 'while(/\G.*?<!--\[STFGMETA\[(.*?)\]STFGMETA\]-->/g) { say $$1; }' < $(word 2,$^) >> $@
	echo ',' >> $@
	echo '"element":' >> $@
	cat $< >> $@
	echo '}' >> $@

$(TIGHT_SHAPES_DIR)/%.svg: $(LOOSE_SHAPES_DIR)/%.svg | $(TIGHT_SHAPES_DIR) $(TIGHT_SHAPES_TEMP_DIR)
	@$(eval ENTRE := $(TIGHT_SHAPES_TEMP_DIR)/$(notdir $@))
	cp $^ $(ENTRE)
	inkscape --verb EditSelectAllInAllLayers --verb SelectionUnion --verb FileSave --verb FileClose $(ENTRE)
	scour -i $(ENTRE) -o $@

