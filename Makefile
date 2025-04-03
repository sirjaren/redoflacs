#
# Makefile for generating redoflacs.1 man page from Markdown source
#

# Generate redoflacs.1 man page
man: docs/redoflacs.1.md
	pandoc --standalone --to man docs/redoflacs.1.md -o redoflacs.1

# Clean the generated man page
clean:
	rm -f redoflacs.1
