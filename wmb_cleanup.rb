#!ruby
require 'optparse'
require 'yaml'
require_relative 'lib/bayonetta.rb'
include Bayonetta

$options = {
  :vertexes => false,
  :bones => false,
  :textures => false,
  :cleanup_mat => false,
  :cleanup_mat_sizes => false,
  :maximize_mat_sizes => false,
  :delete_bones => nil,
  :offsets => false,
  :fix => false,
  :swap => nil,
  :swap_meshes => nil,
  :delete_meshes => nil,
  :merge_meshes => nil,
  :overwrite => nil
}

OptionParser.new do |opts|
  opts.banner = "Usage: wmb_cleanup.rb target_file [options]"

  opts.on("--[no-]bone-refs", "Cleanup bone refs in batches") do |bone_refs|
    $options[:bone_refs] = bone_refs
  end

  opts.on("-b", "--[no-]bones", "Cleanup bones") do |bones|
    $options[:bones] = bones
  end

  opts.on("-v", "--[no-]vertexes", "Cleanup vertexes") do |vertexes|
    $options[:vertexes] = vertexes
  end

  opts.on("--[no-]normalize-vertex-usage", "Ensure no vertex is used in more than 1 batch") do |nvu|
    $options[:normalize_vertex_usage] = nvu
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

  opts.on("--duplicate-meshes=MESHLIST", "Duplicate specified meshes") do |mesh_list|
    $options[:duplicate_meshes] = eval(mesh_list).to_a
  end

  opts.on("-s", "--swap-meshes=MESHHASH", "Swap specified meshes") do |mesh_hash|
    $options[:swap_meshes] = eval(mesh_hash).to_h
  end

  opts.on("--merge-meshes=MESHHASH", "Merge specified meshes") do |mesh_hash|
    $options[:merge_meshes] = eval(mesh_hash).to_h
  end

  opts.on("-m", "--delete-meshes=MESHLIST", "Delete specified meshes") do |mesh_list|
    $options[:delete_meshes] = eval(mesh_list).to_a
  end

  opts.on("-d", "--delete-bones=BONELIST", "Delete specified bones") do |bone_list|
    $options[:delete_bones] = eval(bone_list).to_a
  end

  opts.on("-t", "--[no-]textures", "Cleanup textures") do |textures|
    $options[:textures] = textures
  end

  opts.on("-c", "--cleanup-materials", "Cleanup materials") do |cleanup_mat|
    $options[:cleanup_mat] = cleanup_mat
  end

  opts.on("--cleanup-material-sizes", "Cleanup material sizes") do |cleanup_mat_sizes|
    $options[:cleanup_mat_sizes] = cleanup_mat_sizes
  end

  opts.on("--maximize-material-sizes", "Maximize material sizes") do |cleanup_mat_sizes|
    $options[:maximize_mat_sizes] = cleanup_mat_sizes
  end

  opts.on("--overwrite", "Overwrite input file") do |overwrite|
    $options[:overwrite] = overwrite
  end

  opts.on("--scale=SCALE", "Scales the model by a factor") do |scale|
    $options[:scale] = scale.to_f
  end

  opts.on("--shift=SHIFT_VECTOR", "Shifts the model") do |shift|
    $options[:shift] = eval(shift).to_a
  end

  opts.on("--reverse-tangents-byte-order=MESH_LIST", "Fixes the tangents import that was buggy, only use on bayo 2 imported meshes...") do |tan|
    $options[:reverse_tangents] = eval(tan).to_a
  end

  opts.on("--[no-]recompute-relative-positions", "Recomputes relative bone positions...") do |recomp|
    $options[:recompute_relative_positions] = recomp
  end

  opts.on("--set-pose=POSE_FILE", "Set model to the given pose") do |pose|
    $options[:set_pose] = YAML::load_file(pose)
  end

  opts.on("--[no-]set-t-pose", "Set the model to a t pose (WMB3)") do |tpose|
    $options[:set_tpose] = tpose
  end

  opts.on("--rotate=ROTATE_INFO", "Rotates the model.",
                                  "  ROTATE_INFO is either:",
                                  "    [rx, ry, rz] rotation (in radian) respectively around the x, y and z axis (in this order)",
                                  "    [[rx, ry, rz], [x, y, z]] with the center of the rotation specified" ) do |rotate|
    $options[:rotate] = eval(rotate).to_a
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
wmb.scale($options[:scale]) if $options[:scale]
wmb.rotate(*($options[:rotate])) if $options[:rotate]
wmb.shift(*($options[:shift])) if $options[:shift]
wmb.duplicate_meshes($options[:duplicate_meshes]) if $options[:duplicate_meshes]
wmb.swap_meshes($options[:swap_meshes]) if $options[:swap_meshes]
wmb.merge_meshes($options[:merge_meshes]) if $options[:merge_meshes]
wmb.delete_meshes($options[:delete_meshes]) if $options[:delete_meshes]
wmb.cleanup_bone_refs if $options[:bone_refs]
wmb.cleanup_bones if $options[:bones]
wmb.recompute_relative_positions if $options[:recompute_relative_positions]
wmb.normalize_vertex_usage if $options[:normalize_vertex_usage]
wmb.cleanup_vertexes if $options[:vertexes]
wmb.remove_batch_vertex_offsets if $options[:offsets]
wmb.fix_ex_data if $options[:fix]
wmb.reverse_tangents_byte_order($options[:reverse_tangents]) if $options[:reverse_tangents]
if $options[:set_pose]
  exp_name = input_file.gsub(".wmb", ".exp")
  exp = nil
  if File::file?(exp_name)
    exp = EXPFile::load(exp_name)
  end
  wmb.set_pose($options[:set_pose], exp)
end
if $options[:set_tpose]
  wmb.set_tpose
end
wmb.delete_bones($options[:delete_bones]) if $options[:delete_bones]
wmb.cleanup_materials if $options[:cleanup_mat]
wmb.cleanup_material_sizes if $options[:cleanup_mat_sizes]
wmb.maximize_material_sizes if $options[:maximize_mat_sizes]
wmb.cleanup_textures(input_file, $options[:overwrite]) if $options[:textures]
unless wmb.class == WMB3File
  wmb.renumber_batches
  wmb.recompute_layout
end
if $options[:overwrite]
  wmb.dump(input_file, $options[:swap] ? !wmb.was_big? : wmb.was_big? )
else
  wmb.dump("wmb_output/"+File.basename(input_file), $options[:swap] ? !wmb.was_big? : wmb.was_big? )
end
