#!ruby
require 'optparse'
require 'yaml'
require_relative 'lib/bayonetta.rb'
include Bayonetta

$options = {
  :vertexes => true,
  :bones => false,
  :textures => false,
  :cleanup_mat_sizes => false,
  :maximize_mat_sizes => false,
  :delete_bones => nil,
  :offsets => false,
  :fix => false,
  :swap => nil,
  :swap_meshes => nil,
  :delete_meshes => nil
}

OptionParser.new do |opts|
  opts.banner = "Usage: wmb_cleanup.rb target_file [options]"

  opts.on("-b", "--[no-]bones", "Cleanup bones") do |bones|
    $options[:bones] = bones
  end

  opts.on("-v", "--[no-]vertexes", "Cleanup vertexes") do |vertexes|
    $options[:vertexes] = vertexes
  end

  opts.on("-o", "--[no-]remove-batch-offsets", "Remove batch vertex offsets") do |o|
    $options[:offsets] = o
  end

  opts.on("-f", "--[no-]fix-ex-data", "Put normal map u v in ex data") do |fix|
    $options[:fix] = fix
  end

  opts.on("-e", "--swap-endianness", "Swap endianness") do |swap|
    $options[:swap] = swap
  end

  opts.on("-s", "--swap-meshes=MESHHASH", "Swap specified meshes") do |mesh_hash|
    $options[:swap_meshes] = eval(mesh_hash).to_h
  end

  opts.on("-m", "--delete-meshes=MESHList", "Delete specified meshes") do |mesh_list|
    $options[:delete_meshes] = eval(mesh_list).to_a
  end

  opts.on("-d", "--delete-bones=BONELIST", "Delete specified bones") do |bone_list|
    $options[:delete_bones] = eval(bone_list).to_a
  end

  opts.on("-t", "--[no-]textures", "Cleanup materials and textures") do |textures|
    $options[:textures] = textures
  end

  opts.on("--cleanup-material-sizes", "Cleanup material sizes") do |cleanup_mat_sizes|
     $options[:cleanup_mat_sizes] = cleanup_mat_sizes
  end

  opts.on("--maximize-material-sizes", "Maximize material sizes") do |cleanup_mat_sizes|
     $options[:maximize_mat_sizes] = cleanup_mat_sizes
  end

  opts.on("-h", "--help", "Prints this help") do
    puts opts
    exit
  end

end.parse!


input_file = ARGV[0]

raise "Invalid file #{input_file}" unless File::file?(input_file)
Dir.mkdir("wmb_output") unless Dir.exist?("wmb_output")
Dir.mkdir("wtb_output") unless Dir.exist?("wtb_output")
wmb = WMBFile::load(input_file)
wmb.swap_meshes($options[:swap_meshes]) if $options[:swap_meshes]
wmb.delete_meshes($options[:delete_meshes]) if $options[:delete_meshes]
wmb.cleanup_bones if $options[:bones]
wmb.cleanup_vertexes if $options[:vertexes]
wmb.remove_batch_vertex_offsets if $options[:offsets]
wmb.fix_ex_data if $options[:fix]
wmb.delete_bones($options[:delete_bones]) if $options[:delete_bones]
if $options[:textures]
  wmb.cleanup_materials
end
wmb.cleanup_material_sizes if $options[:cleanup_mat_sizes]
wmb.maximize_material_sizes if $options[:maximize_mat_sizes]
wmb.renumber_batches
wmb.recompute_layout
wmb.dump("wmb_output/"+File.basename(input_file), $options[:swap] ? !wmb.was_big? : wmb.was_big? )
