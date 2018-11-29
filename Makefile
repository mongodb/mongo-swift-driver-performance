# if provided, FILTER is used as the --filter argument to `swift test`. 
ifdef FILTER
	FILTERARG = --filter $(FILTER)
else
	FILTERARG =
endif

define check_for_gem
	gem list $(1) -i > /dev/null || gem install $(1) || { echo "ERROR: Failed to locate or install the ruby gem $(1); please install yourself with 'gem install $(1)' (you may need to use sudo)"; exit 1; }
endef

all:
	swift test $(FILTERARG) | python benchmark.py

# project generates the .xcodeproj, and then modifies it to add
# spec .JSON files to the project
project:
	swift package generate-xcodeproj
	@$(call check_for_gem, xcodeproj)
	ruby add_json_files.rb

lint:
	swiftlint autocorrect
	swiftlint

clean:
	rm -rf MongoSwift-Performance.xcodeproj
	rm -rf Packages
	rm -rf .build
	rm Package.resolved
