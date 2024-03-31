require 'optparse'
require_relative '../../bayonetta'
include Bayonetta

$options = {
  output: nil
}

OptionParser.new do |opts|
  opts.banner = <<EOF
Usage: wmb_convert_wiiu_pc target_file
EOF
  opts.on("-h", "--help", "Prints this help") do
    puts opts
    exit
  end

  opts.on("-o", "--output=filename", "file to output result") do |name|
    $options[:output] = name
  end

end.parse!

input_file = ARGV[0]

raise "Invalid file #{input_file}" unless input_file && File::file?(input_file)

output_file = $options[:output]
if !output_file
  Dir.mkdir("wmb_output") unless Dir.exist?("wmb_output")
  output_file = File.join("wmb_output", File.basename(input_file))
end
WMBFile::convert(input_file, output_file, :swap)
