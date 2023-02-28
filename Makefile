.PHONY: install styles compile serve build develop

install:
	bundle install

compile:
	bundle exec jekyll build

serve:
	bundle exec jekyll serve --watch --livereload

build: install styles compile

develop: install styles serve
