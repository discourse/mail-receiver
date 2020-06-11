all:
	$(MAKE) lint
	$(MAKE) test

.PHONY: all


bundle:
	bundle install --quiet

.PHONY: bundle


lint: bundle
	bundle exec rubocop

.PHONY: lint


test: bundle
	bundle exec rspec

.PHONY: test
