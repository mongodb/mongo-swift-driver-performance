all:
	swift run -c release

lint:
	swiftlint autocorrect
	swiftlint

clean:
	rm -rf .build
	rm Package.resolved
