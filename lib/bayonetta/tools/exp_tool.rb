require 'optparse'
require 'yaml'
require_relative '../../bayonetta.rb'
include Bayonetta

$options = {
  :add => false,
  :overwrite => false,
  :swap => false
}

OptionParser.new do |opts|
  opts.banner = "Usage: exp_tool.rb target_file [options]"

  opts.on("-a", "--add=HASH", "Add entries for the give type example: --add={2=>1, 3=>2} 1 type 2 entry and 2 type 3") { |add|
    $options[:add] = eval(add).to_h
  }

  opts.on("--overwrite", "Overwrite input file") do |overwrite|
    $options[:overwrite] = overwrite
  end

  opts.on("-e", "--swap-endianness", "Swap endianness") do |swap|
    $options[:swap] = swap
  end

  opts.on("-h", "--help", "Prints this help") do
    puts opts
    exit
  end

end.parse!

Dir.mkdir("exp_output") unless Dir.exist?("exp_output")
input_file = ARGV[0]
raise "Invalid file #{input_file}" unless File::file?(input_file)

exp = EXPFile::load(input_file)

exp.add_entries($options[:add]) if $options[:add]

exp.recompute_layout

if $options[:overwrite]
  exp.dump(input_file, $options[:swap] ? !exp.was_big? : exp.was_big? )
else
  exp.dump("exp_output/"+File.basename(input_file), $options[:swap] ? !exp.was_big? : exp.was_big? )
end
