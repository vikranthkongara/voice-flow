# Voice Flow - Builder Toolbox bundler + publisher

TOOL_NAME := voice-flow
VERSION := $(shell cat VERSION)
BUNDLE_DIR := build/bundle
PYTHON_VERSION := 3.11
WHISPER_MODEL := base

# Platform detection
UNAME_M := $(shell uname -m)
ifeq ($(UNAME_M),arm64)
    PLATFORM := macos_arm64
else
    PLATFORM := macos_x86_64
endif

.PHONY: all clean bundle publish

all: bundle

clean:
	rm -rf build/ dist/ .venv-bundle/

# Create a self-contained bundle with embedded Python + deps + Whisper model
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

	# Create launcher script
	cat > $(BUNDLE_DIR)/bin/voice-flow << 'LAUNCHER'
#!/bin/bash
TOOL_ROOT="$$(cd "$$(dirname "$$0")/.." && pwd)"
export PYTHONPATH="$$TOOL_ROOT/lib:$$PYTHONPATH"
export XDG_CACHE_HOME="$$TOOL_ROOT/models"
exec python3 "$$TOOL_ROOT/lib/voice_flow.py" "$$@"
LAUNCHER
	chmod +x $(BUNDLE_DIR)/bin/voice-flow

	# Create local-only launcher
	cat > $(BUNDLE_DIR)/bin/voice-flow-local << 'LAUNCHER'
#!/bin/bash
TOOL_ROOT="$$(cd "$$(dirname "$$0")/.." && pwd)"
export PYTHONPATH="$$TOOL_ROOT/lib:$$PYTHONPATH"
export XDG_CACHE_HOME="$$TOOL_ROOT/models"
exec python3 "$$TOOL_ROOT/lib/voice_flow_local.py" "$$@"
LAUNCHER
	chmod +x $(BUNDLE_DIR)/bin/voice-flow-local

	# Create setup script for first-run permissions
	cp setup-permissions.sh $(BUNDLE_DIR)/bin/voice-flow-setup
	chmod +x $(BUNDLE_DIR)/bin/voice-flow-setup

	@echo "=== Bundle complete: $(BUNDLE_DIR) ==="

# Publish to S3 toolbox repository
publish: bundle
	@echo "=== Publishing $(TOOL_NAME) $(VERSION) to S3 ==="
	toolbox-publisher \
		--tool $(TOOL_NAME) \
		--version $(VERSION) \
		--platform $(PLATFORM) \
		--source $(BUNDLE_DIR) \
		--channel stable
	@echo "=== Published! ==="
