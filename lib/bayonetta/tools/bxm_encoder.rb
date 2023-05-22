require 'optparse'
require 'nokogiri'
require_relative '../../bayonetta'
include Bayonetta

options = {
  tag: :BXM,
  output: nil
}

opts = OptionParser.new do |parser|
  parser.banner = <<EOF
Usage: bxm_encoder [options] [XML_FILE]
  Encode the pecified xml file int binary xml format. Unlessspecified
  output will be along with the original file with a bxm extension.
  If no file is given use stdin, but --output must be specified.
EOF
  parser.on("-t", "--tag TAG", [:XML, :BXM], "Select tag to use (BXM, XML) default BXM")
  parser.on("-o", "--output filename", "Select output file name")
end
opts.parse!(into: options)

tag = (options[:tag].to_s + "\0").b

output_name = options[:output]
if ARGV[0]
  ouput_name = File.join(File.dirname(ARGV[0]), File.basename(ARGV[0], File.extname(ARGV[0])))+".bxm" unless output_name
  input_file = File::open(ARGV[0], "rb")
else
  raise "unspecified output file" unless output_name
  input_file = $stdin
end

bxm = BXMFile::from_xml(Nokogiri::XML(input_file.read), tag)
bxm.dump(output_name)

input_file.close if ARGV[0]
