#!ruby
require_relative 'lib/bayonetta.rb'
require 'nokogiri'
include Bayonetta
require 'optparse'

options = { tag: :BXM }

opts = OptionParser.new do |parser|
  parser.banner = "Usage: ruby bxm_decoder.rb [options] XML_FILE"
  parser.on("-t", "--tag TAG", [:XML, :BXM], "Select tag to use (BXM, XML) default BXM")
end
opts.parse!(into: options)

tag = options[:tag].to_s + "\0"

input_file = ARGV[0]
unless  ARGV[0]
  puts opts
  exit 1
end

File::open(input_file, "rb") { |f|
  bxm = BXMFile::from_xml(Nokogiri::XML(f.read), tag)
  bxm.dump(File.join(File.dirname(ARGV[0]), File.basename(ARGV[0], File.extname(ARGV[0])))+".bxm")
}
