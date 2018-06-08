#!ruby
require_relative 'lib/bayonetta.rb'
include Bayonetta


input_file = ARGV[0]

raise "Invalid file #{input_file}" unless File::file?(input_file)
Dir.mkdir("mot_output") unless Dir.exist?("mot_output")
fl = MOTFile::convert(input_file, "mot_output/"+File.basename(input_file))

