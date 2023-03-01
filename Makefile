.PHONY: install compile serve

install:
	bundle install

compile:
	bundle exec jekyll build

serve:
	bundle exec jekyll serve --watch --livereload
