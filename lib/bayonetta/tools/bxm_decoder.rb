require 'optparse'
require_relative '../../bayonetta'
include Bayonetta

OptionParser.new do |opts|
  opts.banner = <<EOF
Usage: bxm_decoder target_file
  Decode the target bxm file into xml

EOF
  opts.on("-h", "--help", "Prints this help") do
    puts opts
    exit
  end

end.parse!

input_file = ARGV[0]

File::open(input_file, "rb") { |f|
  bxm = BXMFile::load(f)
  print bxm.to_xml
}
