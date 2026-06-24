# ─── Snapix dev commands ───────────────────────────────────────────────────────
DEFINES := --dart-define-from-file=dart_defines.json

.PHONY: run run-ios run-android build-ios build-android clean

## Default: run on the first available device
run:
	flutter run $(DEFINES) $(ARGS)

## Explicit iOS simulator target
run-ios:
	flutter run $(DEFINES) -d "iPhone 17 Pro Max" $(ARGS)

## Explicit Android target
run-android:
	flutter run $(DEFINES) -d $(shell flutter devices | grep android | awk '{print $$4}' | head -1) $(ARGS)

## Build
build-ios:
	flutter build ios $(DEFINES) --no-codesign $(ARGS)

build-android:
	flutter build apk $(DEFINES) $(ARGS)

## Nuke build artefacts
clean:
	flutter clean
