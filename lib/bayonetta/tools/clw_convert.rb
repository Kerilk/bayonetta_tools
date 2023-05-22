require 'optparse'
require_relative '../../bayonetta'
require 'yaml'
include Bayonetta
$bone_map = { }
$options = {
  remap_bones: false,
  output: nil
}
OptionParser.new do |opts|
  opts.banner = <<EOF
Usage: clw_convert target_file [options]
  Convert a Bayonetta 2 _clw.bxm file to bayonetta format, optionally
  remapping the bones, or remap a Bayonetta 1 clw file. By default
  output will be in the ./clx_output folder.
EOF

  opts.on("-r", "--remap-bones=BONELISTS", "Remap specified bones, either lists separated by / or a yaml hash table") do |bone_lists|
    $options[:remap_bones] = true
    if File::exist?(bone_lists)
      $bone_map.merge! YAML::load_file(bone_lists)
    else
      lists = bone_lists.split("/")
      p input_list = eval(lists.first).to_a
      p output_list = eval(lists.last).to_a
      $bone_map.merge! input_list.zip(output_list).to_h
    end
  end

  opts.on("-o", "--output=filename", "file to output result") do |name|
    $options[:output] = name
  end

  opts.on("-h", "--help", "Prints this help") do
    puts opts
    exit
  end

end.parse!

$bone_map.merge!( { -1 => -1 } )

Dir.mkdir("clx_output") unless Dir.exist?("clx_output")

input_file = ARGV[0]
raise "Invalid file #{input_file}" unless input_file && File::file?(input_file)

output_file = $options[:output]

if File.extname(ARGV[0]) == ".bxm"
  raise "Invalid clw file #{input_file}" unless File.basename(ARGV[0]).end_with?("_clw.bxm")
  output_file = File.join("clx_output", File.basename(ARGV[0]).gsub("_clw.bxm",".clw")) unless output_file
  clw = CLWFile::load_bxm(input_file)
else
  raise "Invalid clw file #{input_file}" unless File.basename(ARGV[0]).end_with?(".clw")
  output_file = File.join("clx_output", File.basename(ARGV[0])) unless output_file
  clw = CLWFile::load(input_file)
end
clw.remap($bone_map) if $options[:remap_bones]
clw.dump(output_file)
