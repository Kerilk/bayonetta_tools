require_relative 'lib/bayonetta.rb'
include Bayonetta

input_dir = ARGV[0]


files  = Dir.entries(input_dir)
Dir.chdir(ARGV[0])
files.select! { |f| File.file?(f) && File.extname(f) == ".gtx" }
files.sort!
puts files
Dir.mkdir("wta_output") unless Dir.exist?("wta_output")
files.collect! { |fname| File::new(fname, "rb") }

wtb = WTBFile::new(nil, true, true)
files.each { |f|
  wtb.push(f)
}

wtb.dump("wta_output/#{File.basename(ARGV[0]).gsub("_wta","")}.wta")

