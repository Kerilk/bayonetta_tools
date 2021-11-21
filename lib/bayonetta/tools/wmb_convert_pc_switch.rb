require 'optparse'
require_relative '../../bayonetta.rb'
include Bayonetta

$options = {
  output: nil
}

OptionParser.new do |opts|
  opts.banner = <<EOF
Usage: wmb_convert_pc_switch target_file
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
wmb = WMBFile::load(input_file)
wmb.normals_to_wide

output_file = $options[:output]
if !output_file
  Dir.mkdir("wmb_output") unless Dir.exist?("wmb_output")
  output_file = File.join("wmb_output", File.basename(input_file))
end
wmb.dump(output_file, wmb.was_big?)
