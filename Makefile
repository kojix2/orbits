release ?= 1
static ?= 0
execution_context ?= 1

build_flags :=
ifeq ($(release),1)
build_flags += --release
endif
ifeq ($(static),1)
build_flags += --static
endif
ifeq ($(execution_context),1)
build_flags += -Dexecution_context
endif

.PHONY: build help

build:
	shards build $(strip $(build_flags))

help:
	@echo "Usage: make [target] [release=0|1] [static=0|1] [preview_mt=0|1] [execution_context=0|1]"
	@echo ""
	@echo "Targets:"
	@echo "  build  Build binary with selected flags (default target)"
	@echo "  help   Show this help"
	@echo ""
	@echo "Defaults:"
	@echo "  release=1"
	@echo "  static=0"
	@echo "  preview_mt=1"
	@echo "  execution_context=1"
	@echo ""
	@echo "Examples:"
	@echo "  make"
	@echo "  make static=1"
	@echo "  make release=0 static=1"
