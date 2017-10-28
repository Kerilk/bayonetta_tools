require 'lib/bayonetta.rb'
include Bayonetta

input_dir = ARGV[0]


files  = Dir.entries(input_dir)
Dir.chdir(ARGV[0])
files.select! { |f| File.file?(f) && File.extname(f) == ".dds" }
files.sort!
puts files
Dir.mkdir("wtb_output") unless Dir.exist?("wtb_output")
files.collect! { |fname| BayoTex::new(fname) }

fl = WTBFileLayout::from_files(files)
fl.dump("wtb_output/#{File.basename(ARGV[0])}.wtb")

