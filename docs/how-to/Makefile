#
#
#

BUILDIR?=_build

##
## Pandoc
##
PANDOC?=pandoc
SLIDES_THEME?=white

# if pandoc is not installed, let's use pandocker
ifeq (, $(shell which $(PANDOC)))
	PANDOCKER_TAG?=latest
endif

ifneq ($(PANDOCKER_TAG),)
	PANDOC:=docker run --rm -it --privileged --volume $(CURDIR):/pandoc dalibo/pandocker:$(PANDOCKER_TAG)
endif

PANDOC_ARGS?=--standalone
PANDOC+= $(PANDOC_ARGS)

##
## Source and Objects
##
SOURCE_FILES = $(sort $(wildcard *.ipynb)) # the order is important
MAIN_FILE = _build/how-to.md
LOG_FILES = $(patsubst %.ipynb,%.log, $(SOURCE_FILES))
MD_FILES = $(patsubst %.ipynb,$(BUILDIR)/%.md, $(SOURCE_FILES))
RAW_MD_FILES = $(MD_FILES:.md=.raw.md)
SLIDES_FILES = $(MD_FILES:.md=.slides.html)
HANDOUT_FILES = $(MD_FILES:.md=.handout.pdf)
HANDOUT2_PDF_FILES = $(MD_FILES:.md=.handout2.pdf)
HANDOUT_HTML_FILES = $(MD_FILES:.md=.handout.html)

HOW-TO_RAW_MD = _build/how-to.raw.md
HOW-TO_HANDOUT_PDF = $(HOW-TO_RAW_MD:.raw.md=.handout.pdf)
HOW-TO_HANDOUT_HTML = $(HOW-TO_RAW_MD:.raw.md=.handout.html)
HOW-TO_HANDOUT_EPUB = $(HOW-TO_RAW_MD:.raw.md=.handout.epub)
HOW-TO_SLIDES_HTML = $(HOW-TO_RAW_MD:.raw.md=.slides.html)

.PRECIOUS: $(MD_FILES)

DEBUG ?= 0
ifeq ($(DEBUG), 1)
.PRECIOUS: $(MAIN_FILE) $(MD_FILES)
else
.INTERMEDIATE: $(RAW_MD_FILES)
endif

all: how-to slides handout


raw_markdown: $(RAW_MD_FILES)
markdown: $(MD_FILES) #: build all intermediate markdown files
slides: $(SLIDES_FILES) #: build all presentations
handout: $(HANDOUT_FILES) #: build all handouts in PDF
handout2_pdf: $(HANDOUT2_PDF_FILES)
handout_html: $(HANDOUT_HTML_FILES) #: build all intermediate HTML files

##
##
##

.PHONY: run

run: $(LOG_FILES)
	
%.log: %.ipynb	
	ipython $^ > $@


##
## Build
##

$(HOW-TO_RAW_MD): $(RAW_MD_FILES)
	cat $^  > $@

how-to: $(HOW-TO_HANDOUT_PDF) $(HOW-TO_SLIDES_HTML) #: build the main workshop exports

$(BUILDIR):
	mkdir -p $(BUILDIR)

$(BUILDIR)/%.raw.md: %.ipynb | _venv $(BUILDIR)
	_venv/bin/python3 -m jupyter nbconvert $^ --to markdown --output $@

# pandoc can convert a jupiter notebook to markdown
# BUT nbconvert is way better at this
%.raw_from_pandoc.md: %.ipynb
	$(PANDOC) $^ --output $@

# we need to clean the raw markdown and remove some jupyter specific cells
# nbconvert has a preprocessor for that, but using `sed` is way simpler
%.md: %.raw.md
	cp $^ $@
	# remove jupyter macros
	sed -i '/^%sql/d' $@
	sed -i '/^%%sql/d' $@
	sed -i '/^%%bash/d' $@
	sed -i '/^%%capture/d' $@
	sed -i '/^%reload_ext/d' $@
	sed -i '/^%config/d' $@
	# remove empty python codeblocks
	cat $@ |_venv/bin/python3 -c 'import sys, re; print(re.sub(r"```python\n?\n```", "", sys.stdin.read()))' | tee $@.tmp
	mv $@.tmp $@
	# the remaining python codeblocks are actually SQL codeblocks
	sed -i 's/^```python/```sql/' $@
	# new slide before each table
	sed -i '/^<table>/i ----\n' $@
	# new slide before each SQL code block
	sed -i '/^```sql/i ----\n' $@

%.slides.html: %.md
	$(PANDOC) $^ \
		--to revealjs \
		--slide-level=3 \
		--variable theme=$(SLIDES_THEME) \
		--standalone \
		--self-contained \
		--output $@

%.handout.epub: %.md
	$(PANDOC) $^ --output $@

%.handout.html: %.md
	$(PANDOC) $^ --output $@

# This is does not work because jupyter export tables as raw HTML
# inside the markdown output
%.handout_broken.pdf: %.md
	$(PANDOC) ./tex/pandoc-latex-environment.md $^ \
		--pdf-engine=xelatex \
		--template=eisvogel \
		--filter pandoc-latex-environment \
		--output $@

# use html as source to convert HTML tables
%.handout.pdf: %.handout.html
	$(PANDOC)  $^ \
		--metadata-file=tex/book.yaml \
		--metadata-file=tex/pandoc-latex-environment.yaml \
		--include-in-header=tex/fontawesome.tex \
		--top-level-division=chapter \
		--pdf-engine=xelatex \
		--listings \
		--highlight-style tango \
		--template=eisvogel \
		--output $@

# used for debugging
%.handout.tex: %.handout.html
	$(PANDOC)  $^ \
		--metadata-file=tex/book.yaml \
		--metadata-file=tex/pandoc-latex-environment.yaml \
		--include-in-header=tex/fontawesome.tex \
		--filter pandoc-latex-environment \
		--top-level-division=chapter \
		--pdf-engine=xelatex \
		--listings \
		--highlight-style tango \
		--template=eisvogel \
		--output $@

_venv:
	python3 -m venv $@
	$@/bin/pip install --upgrade pip
	$@/bin/pip install -r requirements.txt --use-deprecated=legacy-resolver

clean: #: remove all built objects
	rm -fr _venv
	rm -fr $(BUILDIR)
	rm -fr $(LOG_FILES)

##
## H E L P
##

default:: help

help::  #: display this message.
	@echo
	@echo "Available targets:"
	@echo
	@gawk 'match($$0, /([^:]*):.+#'': (.*)/, m) { printf "    %-16s%s\n", m[1], m[2]}' $(MAKEFILE_LIST) | sort
	@echo

