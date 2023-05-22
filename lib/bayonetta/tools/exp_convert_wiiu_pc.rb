require 'optparse'
require_relative '../../bayonetta'
include Bayonetta

$options = {
  output: nil
}

OptionParser.new do |opts|
  opts.banner = <<EOF
Usage: exp_convert_wiiu_pc target_file
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
  Dir.mkdir("exp_output") unless Dir.exist?("exp_output")
  output_file = File.join("exp_output", File.basename(input_file))
end
EXPFile::convert(input_file, output_file)
