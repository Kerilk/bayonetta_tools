#!ruby
require 'yaml'
require_relative 'lib/bayonetta'

input_dir = ARGV[0]

raise "Not a directory: #{input_dir}!" unless File.directory?(input_dir)

Dir.chdir(input_dir)
Dir.mkdir("scr_output") unless Dir.exist?("scr_output")

big = YAML::load_file(".metadata/big.yaml")
bayo2 = YAML::load_file(".metadata/bayo2.yaml")

if bayo2
  scr = Bayonetta::SCR2File::new(nil, big)
else
  scr = Bayonetta::SCRFile::new(nil, big)
end

scr.models_metadata = YAML::load_file(".metadata/models_metadata.yaml")
scr.unknown = YAML::load_file(".metadata/unknown.yaml")

files = Dir.entries(".")
models = files.select { |name| name.match "wmb" }
models.sort!
textures = files.select { |name| name.match "wtb" }.first

models.each { |name|
  scr.push_model(File::new(name, "rb"))
}

scr.textures = File::new("000.wtb", "rb") unless bayo2

scr.dump("scr_output/#{File.basename(input_dir).gsub("_scr", ".scr")}")
