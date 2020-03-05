all:
	swift run -c release | python benchmark.py

lint:
	swiftlint autocorrect
	swiftlint

clean:
	rm -rf .build
	rm Package.resolved
