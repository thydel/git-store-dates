#!/usr/bin/make -f

MAKEFLAGS += -Rr
MAKEFLAGS += --warn-undefined-variables
SHELL := $(shell which bash)
.SHELLFLAGS := -euo pipefail -c

.ONESHELL:
.DELETE_ON_ERROR:
.PHONY: phony

.RECIPEPREFIX :=
.RECIPEPREFIX +=

.DEFAULT_GOAL := main

MIN_VERSION := 4.1
VERSION_ERROR :=  make $(MAKE_VERSION) < $(MIN_VERSION)
$(and $(or $(filter $(MIN_VERSION),$(firstword $(sort $(MAKE_VERSION) $(MIN_VERSION)))),$(error $(VERSION_ERROR))),)

self    := $(lastword $(MAKEFILE_LIST))
$(self) := $(basename $(self))
$(self):;

top: phony; @date

################

git.version.min := 2.23.0
git.version.use := $(word 3, $(shell git version))
git.version.seq := <(echo $(git.version.min) $(git.version.use) | xargs -n1)
git.version.cmp != cmp -s <(sort -V $(git.version.seq)) $(git.version.seq) || date
$(if $(git.version.cmp), $(error want git $(git.version.min), found git $(git.version.use)))

################

toplevel != git rev-parse --show-toplevel
$(if $(toplevel),, $(error not in git context))

found := $(toplevel)/.git/hooks/.found-dates
saved := $(toplevel)/.saved-dates

save: phony find $(saved)
main: phony save

find restore: vars := -v RS='\0' -v q='"'

find: find := git ls-files -sz | grep -zve $(notdir $(saved)) | cut -zf2
find: stat := xargs -0 stat -c '%Y %n' | tr '\n' '\0' | sort -zrn
find: awk  := FNR == 1 { print "touch -d @" $$1 FS q "$(found)" q }
find: phony
 @$(find) | $(stat) > $(found)
 awk $(vars) '$(awk)' $(found) | dash
 tr '\0' '\n' < $(found) > $(found)-nozero
 cmp -s $(found) $(saved) || rm -f $(saved)

$(found):;
$(saved): $(found); @cp -p $< $@; git add $@; echo $(self): dates upgraded

show: $(saved) phony; @< $< xargs -0i echo {}

restore: awk := { print "touch -d @" $$1 sprintf("", sub($$1 FS, "")) FS q $$0 q }
restore: phony; @test -f $(saved) && awk $(vars) '$(awk)' $(saved) | dash

hooks: list       := pre-commit post-merge
hooks: pre-commit := \#!/bin/sh\n\ngit-store-dates
hooks: post-merge := $(pre-commit) restore
hooks: links      := $(toplevel)/.git/hooks/%
hooks: files      := $(links).store-dates
hooks: tests      := $(links).tests
hooks: .          := $(eval hooks_files   := $(list:%=$(files)))
hooks: .          := $(eval hooks_links   := $(list:%=$(links)))
hooks: .          := $(eval hooks_tests   := $(list:%=$(tests)))
hooks: .          := $(eval hooks_files_p := $(files))
hooks: .          := $(eval hooks_links_p := $(links))
$(hooks_files): $(hooks_files_p) :; echo -e '$($*)' > $@; chmod +x $@
$(hooks_links_p): $(hooks_files_p); (cd $(@D); ln -s $(<F) $(@F))
$(hooks_tests):
 @test -h $(basename $@) || (test -f $(basename $@) \
 && (echo -e "\n\t*** hook $(basename $(@F)) already exists\n"; exit 1))
hooks: phony $(hooks_files) $(hooks_links) $(hooks_tests);

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
install: phony $(install_list:%=$(install_dir)/%);
else
install: phony; @echo "can't install from installed"
endif

endif
