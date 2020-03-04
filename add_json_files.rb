require 'xcodeproj'

project = Xcodeproj::Project.open('mongo-swift-driver-performance.xcodeproj')
targets = project.native_targets

# make a file reference for the provided project with file at dirPath (relative)
def make_reference(project, path)
    fileRef = project.new(Xcodeproj::Project::Object::PBXFileReference)
    fileRef.path = path
    return fileRef
end

benchmark_target = targets.find { |t| t.uuid == "MongoSwift-Performance::Benchmarks" }
benchmark_data = make_reference(project, "./data")
benchmark_target.add_resources([benchmark_data])

project.save
