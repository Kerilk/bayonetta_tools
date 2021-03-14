#!ruby
require_relative 'lib/bayonetta.rb'
require 'nokogiri'
include Bayonetta

input_file = ARGV[0]

File::open(input_file, "rb") { |f|
  bxm = BXMFile::from_xml(Nokogiri::XML(f.read))
  bxm.dump(File.join(File.dirname(ARGV[0]), File.basename(ARGV[0], File.extname(ARGV[0])))+".bxm")
}
