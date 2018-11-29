require 'xcodeproj'

project = Xcodeproj::Project.open('MongoSwift-Performance.xcodeproj')
targets = project.native_targets

# make a file reference for the provided project with file at dirPath (relative)
def make_reference(project, path)
	fileRef = project.new(Xcodeproj::Project::Object::PBXFileReference)
	fileRef.path = path
	return fileRef
end

benchmark_target = targets.find { |t| t.uuid == "MongoSwift-Performance::Benchmarks" }
benchmark_data = make_reference(project, "./Tests/Benchmarks/data")
benchmark_target.add_resources([benchmark_data])

project.save
