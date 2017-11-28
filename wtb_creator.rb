#!ruby
require_relative 'lib/bayonetta.rb'
include Bayonetta

input_dir = ARGV[0]


files  = Dir.entries(input_dir)
Dir.chdir(ARGV[0])
files.select! { |f| File.file?(f) && File.extname(f) == ".dds" }
files.sort!
puts files
Dir.mkdir("wtb_output") unless Dir.exist?("wtb_output")
files.collect! { |fname| File::new(fname, "rb") }

wtb = WTBFile::new
files.each { |f|
  wtb.push(f)
}

wtb.dump("wtb_output/#{File.basename(ARGV[0]).gsub("_wtb","")}.wtb")

