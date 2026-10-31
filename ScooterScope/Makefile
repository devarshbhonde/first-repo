.PHONY: setup generate open clean

# One-time: installs XcodeGen via Homebrew.
setup:
	brew install xcodegen

# Regenerate the Xcode project from project.yml.
generate:
	xcodegen generate

# Regenerate and open in Xcode.
open: generate
	open ScooterScope.xcodeproj

clean:
	rm -rf ScooterScope.xcodeproj
