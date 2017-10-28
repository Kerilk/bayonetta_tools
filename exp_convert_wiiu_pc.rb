require_relative 'lib/bayonetta.rb'
include Bayonetta


input_file = ARGV[0]

raise "Invalid file #{input_file}" unless File::file?(input_file)
Dir.mkdir("exp_output") unless Dir.exist?("exp_output")
fl = EXPFile::convert(input_file, "exp_output/"+File.basename(input_file))

