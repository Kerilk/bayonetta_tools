#!ruby
require 'optparse'
require 'set'
require_relative 'lib/bayonetta.rb'
require 'yaml'
include Bayonetta

def get_bone_mapping(source, target)
  mapping = source.each.collect { |p|
    distance = [Float::INFINITY, Float::INFINITY]
    min_index = nil
    target.each { |q|
      d = p.distance(q)
      if ( d[0] <= distance[0] && d[1] < distance[1] ) || d[0] < distance[0]
        distance = d
        min_index = q.index
      end
    }
    [p.index, min_index]
  }.to_h
end

def apply_mapping(mapping, meshes)
  meshes.each { |m|
    m.batches.each { |b|
      b.bone_refs.collect! { |i|
        mapping[i]
      }
    }
  }
end

def get_bone_indexes(vertexes)
  s = Set::new
  vertexes.each { |v|
    bi = v.bone_index
    nbi = 0x0
    ia = 4.times.collect { |i|
      ni = bi & 0xff
      bi >>= 8
      s.add(ni)
    }
  }
  s
end

def merge_bones(wmb1, wmb2)

  tt1 = wmb1.bone_index_translate_table.table
  tt2 = wmb2.bone_index_translate_table.table.invert

  bones1 = wmb1.get_bone_structure
  bones2 = wmb2.get_bone_structure

#works but for the arms
#F..ing subtree isomorphism problem
#mapping = get_bone_mapping(bones2, bones1)

  if $options[:bone_map]
    common_mapping = YAML::load_file( $options[:bone_map] )
  else
    common_mapping = {}
  end
#common_bones = YAML::load_file("Bayonetta2_common_bones.yaml")
#mapping = YAML::load_file("Bayo2_pl0010_Bayo_pl0010_bone_mapping.yaml")

  mapping = {}

  tt2.each { |key, val|
    mapping[key] = tt1[common_mapping[val]]
  }
  mapping = mapping.to_a.sort { |e1, e2| e1.first <=> e2.first }.to_h

#missing_bones = mapping.select { |k,v| v.nil? }.collect { |k,v| bones2[k] }
#missing_mapping = get_bone_mapping(missing_bones, bones1)
#p missing_mapping
#mapping.update(missing_mapping)
#p mapping

  mapping[-1] = -1
  missing_bones = mapping.select { |k,v| v.nil? }
  new_bone_index = bones1.size
  new_bone_indexes = []
  missing_bones.each { |bi,_|
    mapping[bi] = new_bone_index
    new_bone_indexes.push(new_bone_index)

    b = bones2[bi].dup
    b.index = new_bone_index
    b.parent = bones1[mapping[b.parent.index]] if b.parent
    b.info = b.info ? b.info : -1
    b.flag = b.flag ? b.flag : 5

    bones1.push b
    new_bone_index += 1
  }
  wmb1.set_bone_structure(bones1)

  missing_bones_count = missing_bones.length

  raise "Too many bones to add!" if missing_bones_count > 0x100

  #missing_bones_slots = align(missing_bones_count, 0x10)/0x10
  (align(missing_bones_count, 0x10) - missing_bones_count).times {
    new_bone_indexes.push(0xfff)
  }

  used_indexes = tt1.keys
  start_index = nil
  #find a free range to add new bone data
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
  }
  wmb1.bone_index_translate_table.table = new_tt

#mapping.each_with_index { |i, j|
#  p = bones2[j]
#  q = bones1[i]
#  puts "#{j} -> #{i} : #{p.distance(q)}"
#}

  apply_mapping(mapping, wmb2.meshes)

end

def merge_vertexes(wmb1, wmb2)
  num_vertex1 = wmb1.header.num_vertexes
  num_vertex2 = wmb2.header.num_vertexes
  wmb1.vertexes += wmb2.vertexes
  wmb1.header.num_vertexes += num_vertex2

  size_vertexes = (num_vertex2 + num_vertex1) * 32


  if wmb1.vertexes_ex_data && wmb2.vertexes_ex_data
    if wmb1.header.vertex_ex_data_size == wmb2.header.vertex_ex_data_size
      wmb1.vertexes_ex_data += wmb2.vertexes_ex_data
    elsif wmb1.header.vertex_ex_data_size == 2 && wmb2.header.vertex_ex_data_size == 1
      wmb1.vertexes_ex_data += num_vertex2.times.collect { |i|
        ex = WMBFile::VertexExData2::new
        #workaroud for bayo 2 here
        ex.unknown = 0xffc0c0c0#wmb2.vertexes_ex_data[i].unknown
        ex.u = wmb2.vertexes[i].u
        ex.v = wmb2.vertexes[i].v
        ex
      }
    end
  end
  return num_vertex1
end

def merge_meshes(wmb1, wmb2)
  new_vertex_offset = wmb1.header.num_vertexes - wmb2.header.num_vertexes
  mesh_offset = align(wmb1.meshes_offsets.last + wmb1.meshes.last.size, 0x20)
  new_meshes_offset = wmb2.meshes_offsets.collect { |e|
    e + mesh_offset
  }
  wmb2.meshes.each_with_index { |m, i|
    m.header.id = i + wmb1.header.num_meshes
    m.batches.each { |b|
      b.header.mesh_id = m.header.id
      b.header.batch_id = 0x0
      if b.header.u_b == 0x81
        b.header.u_b = 0x8001
      end
      if b.header.u_e1 == 0x10
        b.header.u_e1 = 0x0
      elsif b.header.u_e1 == 0x30
        b.header.u_e1 = 0x20
        b.header.u_e2 = 0x0f
      end
      b.header.vertex_start += new_vertex_offset
      b.header.vertex_end += new_vertex_offset
      b.header.vertex_offset += new_vertex_offset
    }
  }

  wmb1.header.num_meshes += wmb2.header.num_meshes
  wmb1.meshes +=  wmb2.meshes
  wmb1.meshes_offsets += new_meshes_offset
end

def merge_materials(wmb1, wmb2, tex_map)
  new_mat_offset = wmb1.header.num_materials
  mat_offset = wmb1.materials_offsets.last + wmb1.materials.last.size
  new_materials_offsets = []
  new_materials = []
  wmb2.materials.each_with_index { |e, i|
    #biggest known material
    new_materials_offsets.push(mat_offset + i*0x124)
    m = WMBFile::Material::new
    m.type = 0x0
    m.flag = 0x0
    m.material_data = [0x0]*(0x120/4)
    m.material_data[0] = (tex_map[e.material_data[0]] ? tex_map[e.material_data[0]] : 0x80000000)
    m.material_data[1] = (tex_map[e.material_data[3]] ? tex_map[e.material_data[3]] : 0x80000000)
    new_materials.push(m)
  }
  wmb2.meshes.each { |m|
    m.batches.each { |b|
      b.header.material_id = b.header.ex_mat_id + new_mat_offset
      b.header.ex_mat_id = 0x0
    }
  }


  wmb1.header.num_materials += wmb2.header.num_materials
  wmb1.materials += new_materials
  wmb1.materials_offsets += new_materials_offsets
end

def recompute_layout(wmb1, wmb2)
  last_offset = wmb1.header.offset_vertexes
  last_offset += wmb1.header.num_vertexes * 32
  last_offset = wmb1.header.offset_vertexes_ex_data = align(last_offset, 0x20)
  last_offset += wmb1.header.num_vertexes * wmb1.header.vertex_ex_data_size * 4
  last_offset = wmb1.header.offset_bone_hierarchy = align(last_offset, 0x20)
  last_offset += 2*wmb1.header.num_bones
  last_offset = wmb1.header.offset_bone_relative_position = align(last_offset, 0x20)
  last_offset += 12*wmb1.header.num_bones
  last_offset = wmb1.header.offset_bone_position = align(last_offset, 0x20)
  last_offset += 12*wmb1.header.num_bones
  last_offset = wmb1.header.offset_bone_index_translate_table = align(last_offset, 0x20)
  last_offset += wmb1.bone_index_translate_table.size
  if wmb1.header.offset_u_j > 0x0
    last_offset = wmb1.header.offset_u_j = align(last_offset, 0x20)
    last_offset += wmb1.u_j.size
  end
  if wmb1.header.offset_bone_infos > 0x0
    last_offset = wmb1.header.offset_bone_infos = align(last_offset, 0x20)
    last_offset += 2*wmb1.header.num_bones
  end
  if wmb1.header.offset_bone_flags > 0x0
    last_offset = wmb1.header.offset_bone_flags = align(last_offset, 0x20)
    last_offset += wmb1.header.num_bones
  end
  if wmb1.header.offset_shader_names > 0x0
    last_offset = wmb1.header.offset_shader_names = align(last_offset, 0x20)
    last_offset += wmb1.header.num_materials * 16
  end
  if wmb1.header.offset_tex_infos > 0x0
    last_offset = wmb1.header.offset_tex_infos = align(last_offset, 0x20)
    last_offset += 4 + wmb1.tex_infos.num_tex_infos * 8
  end

  last_offset = wmb1.header.offset_materials_offsets = align(last_offset, 0x20)
  last_offset += 4*wmb1.header.num_materials
  last_offset = wmb1.header.offset_materials = align(last_offset, 0x20)
  last_offset += wmb1.materials.collect(&:size).reduce(&:+)
  last_offset = wmb1.header.offset_meshes_offsets = align(last_offset, 0x20)
  last_offset += 4*wmb1.header.num_meshes
  last_offset = wmb1.header.offset_meshes = align(last_offset, 0x20)

end

def get_texture_map(tex1, tex2)
  offset = tex1.each.count
  tex_map = {}
  tex2.each.each_with_index { |t,i|
    info, _ = t
    _, _, idx = info
    tex_map[idx] = i+offset
  }
  tex_map
end

class BayoMat
  attr_reader :code
  attr_reader :size
  attr_reader :tex_num
  attr_reader :lightmap_index
  attr_reader :normalmap_index
  attr_reader :second_diffuse_index
  attr_reader :reflection_index
  def initialize(code, size, tex_num, lightmap_index, normalmap_index, second_diffuse_index, reflection_index)
    @code = code
    @size = size
    @tex_num = tex_num
    @lightmap_index = lightmap_index
    @normalmap_index = normalmap_index
    @second_diffuse_index = second_diffuse_index
    @reflexion_index = reflection_index
  end
end

def bayo_mat_properties
  {
    0x31 => BayoMat::new(0x31, 0xC0, 3,  1, -1, -1, -1),
    0x32 => BayoMat::new(0x32, 0xE4, 4,  1, -1, -1,  3),
    0x33 => BayoMat::new(0x33, 0xD4, 4,  2, -1,  1, -1),
    0x34 => BayoMat::new(0x34, 0xF8, 5,  2, -1,  1,  4),
    0x38 => BayoMat::new(0x38, 0xD4, 4, -1,  2, -1, -1),
    0x3A => BayoMat::new(0x3A, 0xD4, 4,  1,  2, -1, -1),
    0x3C => BayoMat::new(0x3C, 0xD4, 4, -1, -1, -1, -1),
    0x40 => BayoMat::new(0x40, 0xC4, 4, -1, -1, -1, -1),
    0x42 => BayoMat::new(0x42, 0xAC, 2, -1, -1, -1, -1),
    0x44 => BayoMat::new(0x44, 0xE4, 4,  1, -1, -1, -1),
    0x47 => BayoMat::new(0x47, 0x68, 1, -1, -1, -1, -1),
    0x48 => BayoMat::new(0x48, 0xC0, 3,  1, -1,  2, -1),
    0x4A => BayoMat::new(0x4A, 0xD4, 4,  2, -1,  1, -1),
    0x4B => BayoMat::new(0x4B, 0xD4, 4, -1,  2, -1, -1),
    0x4C => BayoMat::new(0x4C, 0xAC, 2, -1, -1, -1, -1),
    0x53 => BayoMat::new(0x53, 0x68, 1, -1, -1, -1, -1),
    0x54 => BayoMat::new(0x54, 0xD4, 4,  1, -1, -1, -1),
    0x59 => BayoMat::new(0x59, 0xD4, 4,  1, -1, -1, -1),
    0x60 => BayoMat::new(0x60, 0x68, 1, -1, -1, -1, -1),
    0x68 => BayoMat::new(0x68, 0xAC, 2, -1, -1, -1, -1),
    0x6B => BayoMat::new(0x6B, 0xD0, 3, -1,  1, -1, -1),
    0x6D => BayoMat::new(0x6D, 0xD0, 3, -1,  1, -1, -1),
    0x6E => BayoMat::new(0x6E, 0xD4, 4, -1,  1, -1, -1),
    0x71 => BayoMat::new(0x71, 0xE4, 4,  1, -1, -1, -1),
    0x72 => BayoMat::new(0x72, 0xD4, 4, -1,  1, -1, -1),
    0x75 => BayoMat::new(0x75, 0xAC, 2, -1, -1, -1, -1),
    0x7C => BayoMat::new(0x7C, 0xEA, 4,  1, -1, -1,  3),
    0x7F => BayoMat::new(0x7F, 0x124,4, -1,  1, -1, -1),
    0x81 => BayoMat::new(0x81, 0x120,3, -1, -1, -1, -1),
    0x83 => BayoMat::new(0x83, 0xAC, 2, -1, -1, -1, -1),
    0x87 => BayoMat::new(0x87, 0xD4, 4, -1,  1, -1, -1),
    0x89 => BayoMat::new(0x89, 0xC0, 3,  1, -1, -1,  2),
    0x8F => BayoMat::new(0x8F, 0xD4, 4,  1, -1,  2,  3),
    0x97 => BayoMat::new(0x97, 0x114,4, -1, -1, -1, -1),
    0xA1 => BayoMat::new(0xA1, 0xB0, 3,  1, -1, -1, -1),
    0xA3 => BayoMat::new(0xA3, 0xE4, 4, -1,  1, -1, -1),
    0xB2 => BayoMat::new(0xB2, 0xD4, 4, -1,  1, -1, -1),
    0xB3 => BayoMat::new(0xB3, 0x124,4, -1,  1, -1, -1)
  }
end

def get_shader_map
  {
    "ois00_xbceX" => 0xB3,
    "ois01_xbweX" => 0x7f,
    "ois20_xbceX" => 0xB2,
    "skn03_xbXXX" => 0x87,
    "alp03_sbXXX" => 0x42,
    "har01_sbXtX" => 0x84
  }
end

input_file1 = ARGV[0]
input_file2 = ARGV[1]

$options = {}

OptionParser.new do |opts|
  opts.banner = "Usage: wmb_import_geometry_wiiu_pc.rb target_file source_file [options]"

  opts.on("-bFILE", "--bone-map=FILE", "Bone map") do |bone_map|
    $options[:bone_map] = bone_map
  end

  opts.on("-h", "--help", "Prints this help") do
    puts opts
    exit
  end

end.parse!

raise "Invalid file #{input_file1}" unless File::file?(input_file1)
raise "Invalid file #{input_file2}" unless File::file?(input_file2)

Dir.mkdir("wmb_output") unless Dir.exist?("wmb_output")

wmb1 = WMBFile::load(input_file1)
wmb2 = WMBFile::load(input_file2)


tex1 = WTBFile::new(File::new(input_file1.gsub(/wmb\z/,"wtb"), "rb"))
tex2 = WTBFile::new(File::new(input_file2.gsub(/wmb\z/,"wta"), "rb"), true, File::new(input_file2.gsub(/wmb\z/,"wtp"), "rb"))

p tex_map = get_texture_map(tex1, tex2)

merge_vertexes(wmb1, wmb2)

merge_bones(wmb1, wmb2)

merge_materials(wmb1, wmb2, tex_map)

merge_meshes(wmb1, wmb2)

recompute_layout(wmb1, wmb2)

wmb1.dump("wmb_output/"+File.basename(input_file1))
