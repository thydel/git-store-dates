#!/usr/bin/make -f

MAKEFLAGS += -Rr
SHELL := $(shell which bash)
.RECIPEPREFIX :=
.RECIPEPREFIX +=
.ONESHELL:

toplevel != git rev-parse --show-toplevel
$(if $(toplevel),, $(error not in git context))

found := $(toplevel)/.git/hooks/.found-dates
saved := $(toplevel)/.saved-dates

save: find $(saved)

find restore: vars := -v RS='\0' -v q='"'

find: find := git ls-files -sz | grep -zve $(notdir $(saved)) | cut -zf2
find: stat := xargs -0 stat -c '%Y %n' | tr '\n' '\0' | sort -zrn
find: awk  := FNR == 1 { print "touch -d @" $$1 FS q "$(found)" q }
find:
 @$(find) | $(stat) > $(found)
 awk $(vars) '$(awk)' $(found) | dash
 cmp -s $(found) $(saved) || rm -f $(saved)

$(saved): $(found); @cp -p $< $@; git add $@; echo $(self): dates upgraded

show: $(saved); @< $< xargs -0i echo {}

restore: awk := { print "touch -d @" $$1 sprintf("", sub($$1 FS, "")) FS q $$0 q }
restore:; @test -f $(saved) && awk $(vars) '$(awk)' $(saved) | dash

hooks: list       := pre-commit post-merge
hooks: pre-commit := \#!/bin/sh\n\ngit-store-dates
hooks: post-merge := $(pre-commit) restore
hooks: pattern    := $(toplevel)/.git/hooks/%.store-dates
hooks: .          := $(eval hooks         := $(list:%=$(pattern)))
hooks: .          := $(eval hooks_pattern := $(pattern))
hooks: $(hooks); @echo "link .git/hooks/*.store-dates to activate them"
$(hooks): $(hooks_pattern) :; echo -e '$($*)' > $@; chmod +x $@

.PHONY: find save show restore install hooks

self    := $(lastword $(MAKEFILE_LIST))
$(self) := $(basename $(self))
$(self):;

ifeq ($(MAKECMDGOALS), install)

release != lsb_release -is
ifeq ($(release), Debian)
USER  ?= no_user
staff := staff
$(if $(shell test $(USER) == root || getent group $(staff) | grep -q $(USER) || date),$(error $(USER) not in group $(staff), use "sudo make -f $(self) install"))
endif

ifeq ($(dir $(self)),./)
install_dir := /usr/local/bin
install_list := $(self)
$(install_dir)/%: %; install $< $@; $(if $($*),(cd $(@D); $(strip $(foreach _, $($*), ln -sf $* $_;))))
install: $(install_list:%=$(install_dir)/%);
else
install:; @echo "can't install from installed"
endif

endif
