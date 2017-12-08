#!ruby
require_relative 'lib/bayonetta.rb'
include Bayonetta

input_file = ARGV[0]

File::open(input_file, "rb") { |f|
  bxm = BXMFile::load(f)
  print bxm.to_xml
}
