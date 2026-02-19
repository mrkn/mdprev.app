.PHONY: icon-candidates icon-selected release-app

icon-candidates:
	mkdir -p assets/icon-candidates
	swift -module-cache-path /tmp/swift-module-cache scripts/generate_icon_candidates.swift --out-dir assets/icon-candidates --size 1024

icon-selected:
	mkdir -p assets/app-icon
	bash scripts/build_iconset_from_png.sh assets/app-icon/mdprev-icon-final.png assets/app-icon

release-app: icon-selected
	bash scripts/build_release_app.sh dist
