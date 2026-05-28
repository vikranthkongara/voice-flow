# Voice Flow - Cross-platform Builder Toolbox bundler + publisher

TOOL_NAME := voice-flow
VERSION := $(shell cat VERSION)
BUNDLE_DIR := build/bundle
PYTHON_VERSION := 3.11
WHISPER_MODEL := base

# Platform detection
UNAME_S := $(shell uname -s)
UNAME_M := $(shell uname -m)

ifeq ($(UNAME_S),Darwin)
    ifeq ($(UNAME_M),arm64)
        PLATFORM := macos_arm64
    else
        PLATFORM := macos_x86_64
    endif
else ifeq ($(UNAME_S),Linux)
    PLATFORM := linux_x86_64
else
    PLATFORM := windows_x86_64
endif

.PHONY: all clean bundle publish install-local

all: bundle

clean:
	rm -rf build/ dist/ .venv-bundle/

# Create a self-contained bundle with deps + Whisper model
bundle: clean
	@echo "=== Bundling Voice Flow $(VERSION) for $(PLATFORM) ==="
	mkdir -p $(BUNDLE_DIR)/bin
	mkdir -p $(BUNDLE_DIR)/lib
	mkdir -p $(BUNDLE_DIR)/models

	# Create isolated venv and install deps
	python$(PYTHON_VERSION) -m venv .venv-bundle
	.venv-bundle/bin/pip install --upgrade pip
	.venv-bundle/bin/pip install -r requirements.txt --target $(BUNDLE_DIR)/lib

	# Copy application source
	cp voice_flow.py $(BUNDLE_DIR)/lib/
	cp voice_flow_local.py $(BUNDLE_DIR)/lib/

	# Download Whisper model weights into bundle
	.venv-bundle/bin/python -c "import whisper; whisper.load_model('$(WHISPER_MODEL)', download_root='$(BUNDLE_DIR)/models')"

	# Create launcher scripts
	@echo '#!/bin/bash' > $(BUNDLE_DIR)/bin/voice-flow
	@echo 'TOOL_ROOT="$$(cd "$$(dirname "$$0")/.." && pwd)"' >> $(BUNDLE_DIR)/bin/voice-flow
	@echo 'export PYTHONPATH="$$TOOL_ROOT/lib:$$PYTHONPATH"' >> $(BUNDLE_DIR)/bin/voice-flow
	@echo 'export XDG_CACHE_HOME="$$TOOL_ROOT/models"' >> $(BUNDLE_DIR)/bin/voice-flow
	@echo 'exec python3 "$$TOOL_ROOT/lib/voice_flow.py" "$$@"' >> $(BUNDLE_DIR)/bin/voice-flow
	chmod +x $(BUNDLE_DIR)/bin/voice-flow

	@echo '#!/bin/bash' > $(BUNDLE_DIR)/bin/voice-flow-local
	@echo 'TOOL_ROOT="$$(cd "$$(dirname "$$0")/.." && pwd)"' >> $(BUNDLE_DIR)/bin/voice-flow-local
	@echo 'export PYTHONPATH="$$TOOL_ROOT/lib:$$PYTHONPATH"' >> $(BUNDLE_DIR)/bin/voice-flow-local
	@echo 'export XDG_CACHE_HOME="$$TOOL_ROOT/models"' >> $(BUNDLE_DIR)/bin/voice-flow-local
	@echo 'exec python3 "$$TOOL_ROOT/lib/voice_flow_local.py" "$$@"' >> $(BUNDLE_DIR)/bin/voice-flow-local
	chmod +x $(BUNDLE_DIR)/bin/voice-flow-local

	# Setup script
	cp setup-permissions.sh $(BUNDLE_DIR)/bin/voice-flow-setup
	chmod +x $(BUNDLE_DIR)/bin/voice-flow-setup

	@echo "=== Bundle complete: $(BUNDLE_DIR) ($(PLATFORM)) ==="

# Quick local install (symlinks into ~/.local/bin)
install-local: bundle
	mkdir -p ~/.local/bin
	ln -sf $(abspath $(BUNDLE_DIR)/bin/voice-flow) ~/.local/bin/voice-flow
	ln -sf $(abspath $(BUNDLE_DIR)/bin/voice-flow-local) ~/.local/bin/voice-flow-local
	ln -sf $(abspath $(BUNDLE_DIR)/bin/voice-flow-setup) ~/.local/bin/voice-flow-setup
	@echo "Installed to ~/.local/bin/ — run 'voice-flow-setup' then 'voice-flow'"

# Publish to S3 toolbox repository
publish: bundle
	@echo "=== Publishing $(TOOL_NAME) $(VERSION) for $(PLATFORM) ==="
	toolbox-publisher \
		--tool $(TOOL_NAME) \
		--version $(VERSION) \
		--platform $(PLATFORM) \
		--source $(BUNDLE_DIR) \
		--channel stable
	@echo "=== Published! ==="
