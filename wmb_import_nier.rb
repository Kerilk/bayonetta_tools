#!ruby
require 'optparse'
require 'set'
require_relative 'lib/bayonetta.rb'
require 'yaml'
include Bayonetta

def merge_bones(wmb1, wmb2)

  tt1 = wmb1.bone_index_translate_table.table
  tt2_orig = wmb2.bone_index_translate_table.table
  tt2 = tt2_orig.invert

  bones1 = wmb1.get_bone_structure
  if $options[:bone_map]
    common_mapping = YAML::load_file( $options[:bone_map] )
  else
    common_mapping = {}
  end

  mapping = {}

  tt2.each { |key, val|
    mapping[key] = tt1[common_mapping[val]]
  }
  mapping = mapping.to_a.sort { |e1, e2| e1.first <=> e2.first }.to_h

  if $options[:update_bones]
    mapping.select { |k,v| v }.each { |k,v|
      bones1[v].position = wmb2.bones[k].position
    }
  end

  mapping[-1] = -1
  missing_bones = mapping.select { |k,v| v.nil? }.collect { |k,v| k }
  if $options[:filter_bones]
    missing_bones -= $options[:filter_bones]
  end
  new_bone_index = bones1.size
  new_bone_indexes = []
  missing_bones.each { |bi|
    mapping[bi] = new_bone_index
    new_bone_indexes.push(new_bone_index)

    b = Bone::new(wmb2.bones[bi].position)
    b.index = new_bone_index
    b.parent = bones1[mapping[wmb2.bones[bi].parent_index]] if wmb2.bones[bi].parent_index != -1
    b.symmetric = -1
    b.flag = 5

    bones1.push b
    new_bone_index += 1
  }
  wmb1.set_bone_structure(bones1)
  missing_bones_count = missing_bones.length
  raise "Too many bones to add!" if missing_bones_count > 0x100
  (align(missing_bones_count, 0x10) - missing_bones_count).times {
    new_bone_indexes.push(0xfff)
  }

  used_indexes = tt1.keys
  start_index = nil

  (0x250..(0x1000-new_bone_indexes.size)).step(0x10) { |s_index|
    if (used_indexes & (s_index..(s_index+new_bone_indexes.size)).to_a) == []
      start_index = s_index
      break
    end
  }
  raise "No room available in translate table!" unless start_index
  new_tt = wmb1.bone_index_translate_table.table.dup
  new_bone_indexes.each_with_index { |ind, i|
    new_tt[i+start_index] = ind
    common_mapping[tt2[missing_bones[i]]] = i + start_index if i < missing_bones.length && missing_bones[i]
  }
  wmb1.bone_index_translate_table.table = new_tt

  if wmb1.bone_symmetries
    (-missing_bones_count..-1).each { |i|
      symmetric = common_mapping[wmb1.bone_symmetries[i]]
      symmetric = -1 unless symmetric
      wmb1.bone_symmetries[i] = symmetric
    }
  end

  [common_mapping, mapping]
end

def get_texture_map(tex1, tex2)
  offset = tex1.each.count
  tex_map = {}
  tex2.each.each_with_index { |t,i|
    info, _ = t
    _, _, idx = info
    idx = i unless idx
    tex_map[idx] = i+offset
  }
  tex_map
end

def merge_geometry(wmb1, wmb2, bone_mapping)
  new_meshes = wmb2.header.info_meshes.number.times.collect { WMBFile::Mesh::new }
  new_meshes.each_with_index { |m, i|
    m.header.name = wmb2.meshes[i].name
    m.header.id = i + wmb1.header.num_meshes
  }

  batch_infos_map = {}
  wmb2.lods.each { |l|
    l.batch_infos.each_with_index { |batch_info, i|
      batch_infos_map[i+l.header.batch_start] = batch_info
    }
  }

  vertex_types = wmb1.get_vertex_types

  wmb2.batches.each_with_index { |n_b, batch_index|
    v_g = wmb2.vertex_groups[n_b.vertex_group_index]
    b_s = wmb2.bone_sets[n_b.bone_set_index]
    b = WMBFile::Batch::new
    first_vertex_index = wmb1.vertexes.length
    indices = v_g.indices.values.slice(n_b.index_start, n_b.num_indices)
    index_set = indices.uniq.sort
    num_vertex = index_set.length
    index_map = index_set.each_with_index.collect { |ind, i|
      [ind, i+first_vertex_index]
    }


    wmb1.vertexes += num_vertex.times.collect {
      vertex_types[0]::new
    }
    if wmb1.vertexes_ex_data
      wmb1.vertexes_ex_data += num_vertex.times.collect {
        vertex_types[1]::new
      }
    end
    wmb1.header.num_vertexes += num_vertex

    fields = wmb1.get_vertex_fields
    fields.each { |field|
      unless v_g.get_vertex_field(field, 0)
        warn "Couldn't find vertex field #{field} in model 2"
        if field == :color
          warn "Using default value 0xc0 0xc0 0xc0 0xff"
          c = Color::new
          c.r = 0xc0
          c.g = 0xc0
          c.b = 0xc0
          c.a = 0xff
          index_map.each { |ind, i|
            wmb1.set_vertex_field(field, i, c)
          }
        elsif field == :mapping2
          warn "Using mapping as default"
          index_map.each { |ind, i|
            wmb1.set_vertex_field(field, i, v_g.get_vertex_field(:mapping, ind))
          }
        else
          warn "No suitable default found"
        end
      else
        if field == :normal
          index_map.each { |ind, i|
            n = Normal::new
            n2 = v_g.get_vertex_field(:normal, ind)
            n.x = n2.x
            n.y = n2.y
            n.z = n2.z
            wmb1.set_vertex_field(field, i, n)
          }
        else
          index_map.each { |ind, i|
            wmb1.set_vertex_field(field, i, v_g.get_vertex_field(field, ind))
          }
        end
      end
    }

    index_map = index_map.to_h

    batch_info = batch_infos_map[batch_index]
    mesh = new_meshes[batch_info.mesh_index]

    b.header.material_id = batch_info.material_index + wmb1.header.num_materials
    b.header.mesh_id = mesh.header.id
    b.header.num_indices = indices.length
    b.indices = indices.collect { |ind| index_map[ind] }
    b.recompute_from_absolute_indices
    b.bone_refs = b_s.bone_indices.collect { |bi| bone_mapping[wmb2.bone_map[bi]] }
    b.num_bone_ref = b.bone_refs.length

    mesh.batches.push b
    mesh.header.num_batch += 1
  }

  wmb1.meshes += new_meshes
  wmb1.header.num_meshes += new_meshes.length

end

def merge_materials(wmb1, wmb2, tex_map)
  new_mat_offset = wmb1.header.num_materials
  mat_offset = wmb1.materials_offsets.last + wmb1.materials.last.size
  new_materials_offsets = []
  new_materials = []

  wmb2.materials.each_with_index { |e, i|
    #biggest known material( in fact biggset is 0x174)
    new_materials_offsets.push(mat_offset + i*0x124)
    m = WMBFile::Material::new
    m.type = 0x0
    m.flag = 0x0
    m.material_data = [0x0]*(0x120/4)
    albedo = e.textures.find { |t| t.name.match("g_AlbedoMap") }
    normal = e.textures.find { |t| t.name.match("g_NormalMap") }
    m.material_data[0] = (albedo ? tex_map[albedo.texture_id] : 0x80000000)
    m.material_data[1] = (normal ? tex_map[normal.texture_id] : 0x80000000)
    m.material_data[0] = (m.material_data[0] ? m.material_data[0] : 0x80000000)
    m.material_data[1] = (m.material_data[1] ? m.material_data[1] : 0x80000000)
    new_materials.push(m)
  }

  wmb1.header.num_materials += wmb2.header.info_materials.number
  wmb1.materials += new_materials
  wmb1.materials_offsets += new_materials_offsets
end

$options = {}

OptionParser.new do |opts|
  opts.banner = "Usage: wmb_import_geometry_wiiu_pc.rb target_file source_file [options]"

  opts.on("-bFILE", "--bone-map=FILE", "Bone map") do |bone_map|
    $options[:bone_map] = bone_map
  end

  opts.on("-u", "--update-bones", "Update recognized bone positions") do |update_bones|
    $options[:update_bones] = update_bones
  end

  opts.on("-t", "--[no-]import-textures", "Import textures also") do |import_textures|
    $options[:import_textures] = import_textures
  end

  opts.on("-o", "--[no-]overwrite", "Overwrite destination files") do |overwrite|
    $options[:overwrite] = overwrite
  end

  opts.on("-f", "--filter-bones=REJECT_LIST", "Don't import all bones") do |filter_bones|
     $options[:filter_bones] = eval(filter_bones)
  end

  opts.on("-h", "--help", "Prints this help") do
    puts opts
    exit
  end

end.parse!

input_file1 = ARGV[0]
input_file2 = ARGV[1]

raise "Invalid file #{input_file1}" unless File::file?(input_file1)
raise "Invalid file #{input_file2}" unless File::file?(input_file2)

Dir.mkdir("wmb_output") unless Dir.exist?("wmb_output")

wmb1 = WMBFile::load(input_file1)
wmb2 = WMBFile::load(input_file2)

tex1_file_name = input_file1.gsub(/wmb\z/,"wtb")
tex1 = WTBFile::new(File::new(tex1_file_name, "rb"))
begin
  tex2_file_name = input_file2.gsub(/wmb\z/,"wta")
  tex2 = WTBFile::new(File::new(tex2_file_name, "rb"), true, File::new(input_file2.gsub(/wmb\z/,"wtp"), "rb"))
rescue
  tex2_file_name = input_file2.gsub(/wmb\z/,"wtb")
  tex2 = WTBFile::new(File::new(tex2_file_name, "rb"))
end

tex_map = get_texture_map(tex1, tex2)

common_mapping, bone_mapping = merge_bones(wmb1, wmb2)

merge_geometry(wmb1, wmb2, bone_mapping)

merge_materials(wmb1, wmb2, tex_map)

wmb1.recompute_relative_positions
wmb1.recompute_layout

File::open("wmb_output/#{File::basename(input_file2,".wmb")}_#{File::basename(input_file1,".wmb")}_bone_map.yaml", "w") { |f|
  f.write YAML::dump(common_mapping)
}

if $options[:overwrite]
  wmb1.dump(input_file1)
else
  wmb1.dump("wmb_output/"+File.basename(input_file1))
end

if $options[:import_textures]
  `ruby wtb_import_textures.rb "#{tex1_file_name}" "#{tex2_file_name}"#{$options[:overwrite] ? " --overwrite" : ""}`
end
