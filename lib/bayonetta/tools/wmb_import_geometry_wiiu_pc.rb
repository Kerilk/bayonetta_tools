require 'optparse'
require 'set'
require_relative '../../bayonetta.rb'
require 'yaml'
require 'shellwords'
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
  tt2_orig = wmb2.bone_index_translate_table.table
  tt2 = tt2_orig.invert

  bones1 = wmb1.get_bone_structure
  bones2 = wmb2.get_bone_structure

#works but for the arms
#F..ing subtree isomorphism problem
#mapping = get_bone_mapping(bones2, bones1)

  if $options[:bone_map]
    if $options[:bone_map] == "same"
      common_mapping = tt2_orig.keys.collect { |k| [k,k] }.to_h
    else
      common_mapping = YAML::load_file( $options[:bone_map] )
    end
  else
    common_mapping = {}
  end
#common_bones = YAML::load_file("Bayonetta2_common_bones.yaml")
#mapping = YAML::load_file("Bayo2_pl0010_Bayo_pl0010_bone_mapping.yaml")

  #mapping in local indexes
  mapping = {}

  tt2.each { |key, val|
    mapping[key] = tt1[common_mapping[val]]
  }
  mapping = mapping.to_a.sort { |e1, e2| e1.first <=> e2.first }.to_h

  #update bone positions to meet imported model's ones.
  if $options[:update_bones]
    mapping.select { |k,v| v }.each { |k,v|
      bones1[v].position = bones2[k].position
    }
  end
#missing_bones = mapping.select { |k,v| v.nil? }.collect { |k,v| bones2[k] }
#missing_mapping = get_bone_mapping(missing_bones, bones1)
#p missing_mapping
#mapping.update(missing_mapping)
#p mapping

  mapping[-1] = -1
  missing_bones = mapping.select { |k,v| v.nil? }.collect { |k,v| k }
  new_bone_index = bones1.size
  new_bone_indexes = []
  missing_bones.each { |bi|
    mapping[bi] = new_bone_index
    new_bone_indexes.push(new_bone_index)

    b = bones2[bi].dup
    b.index = new_bone_index
    b.parent = bones1[mapping[b.parent.index]] if b.parent
    b.symmetric = b.symmetric ? b.symmetric : -1
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
    common_mapping[tt2[missing_bones[i]]] = i + start_index if i < missing_bones.length && missing_bones[i]
  }
  wmb1.bone_index_translate_table.table = new_tt

  #update bone symmetries
  if wmb1.bone_symmetries
    (-missing_bones_count..-1).each { |i|
      symmetric = common_mapping[wmb1.bone_symmetries[i]]
      symmetric = -1 unless symmetric
      wmb1.bone_symmetries[i] = symmetric
    }
  end
#mapping.each_with_index { |i, j|
#  p = bones2[j]
#  q = bones1[i]
#  puts "#{j} -> #{i} : #{p.distance(q)}"
#}

  apply_mapping(mapping, wmb2.meshes)

  common_mapping
end

def merge_vertexes(wmb1, wmb2)
  num_vertex1 = wmb1.header.num_vertexes
  num_vertex2 = wmb2.header.num_vertexes

  vertex_types = wmb1.get_vertex_types

  wmb1.vertexes += num_vertex2.times.collect {
    vertex_types[0]::new
  }

  if wmb1.vertexes_ex_data
    wmb1.vertexes_ex_data += num_vertex2.times.collect {
      vertex_types[1]::new
    }
  end

  wmb1.header.num_vertexes += num_vertex2

  wmb1.get_vertex_fields.each { |field|
    unless wmb2.get_vertex_field(field, 0)
      warn "Couldn't find vertex field #{field} in model 2"
      if field == :color
        warn "Using default value 0xc0 0xc0 0xc0 0xff"
        c = Color::new
        c.r = 0xc0
        c.g = 0xc0
        c.b = 0xc0
        c.a = 0xff
        num_vertex2.times { |i|
          wmb1.set_vertex_field(field, num_vertex1 + i, c)
        }
      elsif field == :mapping2
        warn "Using mapping as default"
        num_vertex2.times { |i|
          wmb1.set_vertex_field(field, num_vertex1 + i, wmb2.get_vertex_field(:mapping, i))
        }
      else
        warn "No suitable default found..."
      end
    else
      num_vertex2.times { |i|
        wmb1.set_vertex_field(field, num_vertex1 + i, wmb2.get_vertex_field(field, i))
      }
    end
  }
  return num_vertex1
end

def merge_meshes(wmb1, wmb2)
  new_vertex_offset = wmb1.header.num_vertexes - wmb2.header.num_vertexes
  mesh_offset = align(wmb1.meshes_offsets.last + wmb1.meshes.last.__size, 0x20)
  new_meshes_offset = wmb2.meshes_offsets.collect { |e|
    e + mesh_offset
  }
  wmb2.meshes.each_with_index { |m, i|
    m.header.id = i + wmb1.header.num_meshes
    m.batches.each { |b|
      b.header.mesh_id = m.header.id
      if !wmb1.is_bayo2? && wmb2.is_bayo2?
        b.header.batch_id = 0x0
        b.header.flags = 0x8001
        if b.header.u_e1 == 0x10
          b.header.u_e1 = 0x0
        elsif b.header.u_e1 == 0x30
          b.header.u_e1 = 0x20
          b.header.u_e2 = 0x0f
        end
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
  mat_offset = wmb1.materials_offsets.last + wmb1.materials.last.__size
  new_materials_offsets = []
  new_materials = []
  if wmb2.tex_infos then #Bayo 2
    wmb2.materials.each_with_index { |e, i|
      #biggest known material( in fact biggset is 0x174)
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
  else #Bayo 1
    wmb2.materials.each_with_index { |e, i|
      new_materials_offsets.push(mat_offset)
      mat_offset += e.__size
      m = WMBFile::Material::new
      m.type = e.type
      m.flag = e.flag
      m.material_data = e.material_data.dup
      if bayo_mat_properties[m.type]
        bayomat = bayo_mat_properties[m.type]
        bayomat.tex_num.times { |j|
          m.material_data[j] = ( tex_map[e.material_data[j]] ? tex_map[e.material_data[j]] : e.material_data[j] )
        }
      else
        warn "Unknow material type 0x#{m.type.to_s(16)}!"
        5.times { |j|
          m.material_data[j] = ( tex_map[e.material_data[j]] ? tex_map[e.material_data[j]] : e.material_data[j] )
        }
      end
      new_materials.push(m)
    }
    wmb2.meshes.each { |m|
      m.batches.each { |b|
        b.header.material_id = b.header.material_id + new_mat_offset
      }
    }
  end


  wmb1.header.num_materials += wmb2.header.num_materials
  wmb1.materials += new_materials
  wmb1.materials_offsets += new_materials_offsets
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

@material_database = YAML::load_file(File.join(__dir__,"..", "material_database.yaml"))
@mat_properties = @material_database.select { |k, h|
  h[:layout]
}.collect { |k, h|
  tex_num = h[:layout].count { |k, v| v.match("sampler") }
  lightmap_index = h[:layout].find_index { |k, v| k == "lightmap" && v.match("sampler") }
  lightmap_index = -1 unless lightmap_index
  normalmap_index = h[:layout].find_index { |k, v| k == "reliefmap" && v.match("sampler") }
  normalmap_index = -1 unless normalmap_index
  second_diffuse_index = h[:layout].find_index { |k, v| k == "Color_2" && v.match("sampler") }
  second_diffuse_index = -1 unless second_diffuse_index
  reflection_index = h[:layout].find_index { |k, v| k == "envmap" && v.match("sampler") }
  reflection_index = -1 unless reflection_index
  mat_info = BayoMat.new(k, h[:size], tex_num, lightmap_index, normalmap_index, second_diffuse_index, reflection_index)
  [k, mat_info]
}.to_h

def bayo_mat_properties
  return @mat_properties
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

tex_map = {}

if $options[:import_textures]
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
end

merge_vertexes(wmb1, wmb2)

common_mapping = merge_bones(wmb1, wmb2)

merge_materials(wmb1, wmb2, tex_map)

merge_meshes(wmb1, wmb2)

wmb1.recompute_relative_positions if $options[:update_bones]

wmb1.recompute_layout

File::open(File.join("wmb_output","#{File::basename(input_file2,".wmb")}_#{File::basename(input_file1,".wmb")}_bone_map.yaml"), "w") { |f|
  f.write YAML::dump(common_mapping)
}

if $options[:overwrite]
  wmb1.dump(input_file1)
else
  wmb1.dump(File.join("wmb_output",File.basename(input_file1)))
end

if $options[:import_textures]
  `ruby #{Shellwords.escape File.join(__dir__,"wtb_import_textures.rb")} #{Shellwords.escape tex1_file_name} #{Shellwords.escape tex2_file_name}#{$options[:overwrite] ? " --overwrite" : ""}`
end
