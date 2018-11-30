all:
	$(MAKE) lint
	$(MAKE) test

.PHONY: all


lint:
	rubocop

.PHONY: lint


test:
	rspec

.PHONY: test
