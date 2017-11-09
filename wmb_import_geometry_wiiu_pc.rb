require 'set'
require_relative 'lib/bayonetta.rb'
require 'yaml'
include Bayonetta

class Bone
  attr_accessor :parent
  attr_accessor :children
  attr_accessor :index
  attr_accessor :x, :y, :z
  def initialize( x, y, z)
    @x = x
    @y = y
    @z = z
    @children = []
  end

  def depth
    if parent then
      return parent.depth + 1
    else
      return 0
    end
  end

  def to_s
    "<#{@index}#{@parent ? " (#{@parent.index})" : ""}: #{@x}, #{@y}, #{@z}, d: #{depth}>"
  end

  def inspect
    to_s
  end

  def distance(other)
    d = (@x - other.x)**2 + (@y - other.y)**2 + (@z - other.z)**2
    dd = (depth - other.depth).abs
    [d, dd]
  end

end


input_file1 = ARGV[0]
input_file2 = ARGV[1]

raise "Invalid file #{input_file1}" unless File::file?(input_file1)
raise "Invalid file #{input_file2}" unless File::file?(input_file2)

Dir.mkdir("wmb_output") unless Dir.exist?("wmb_output")

wmb1 = WMBFile::load(input_file1)
wmb2 = WMBFile::load(input_file2)

def get_bone_structure(wmb)

  bones = wmb.bone_positions.collect { |p, i|
    Bone::new(*([p.x, p.y, p.z].pack("L3").unpack("f3")))
  }
  bones.each_with_index { |b, i|
    if wmb.bone_hierarchy[i] == -1
      b.parent = nil
    else
      b.parent = bones[wmb.bone_hierarchy[i]]
      bones[wmb.bone_hierarchy[i]].children.push(b)
    end
    b.index = i
  }
end

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

def decode_bone_index_translate_table(wmb)
  table = wmb.bone_index_translate_table.table
  (0x0..0xfff).each.collect { |i|
    index = table[(i & 0xf00)>>8]
    next if index == -1
    index = table[index + ((i & 0xf0)>>4)]
    next if index == -1
    index = table[index + (i & 0xf)]
    next if index == 0xfff
    [i, index]
  }.compact
end

tt1 = decode_bone_index_translate_table(wmb1).to_h
tt2 = decode_bone_index_translate_table(wmb2).to_h.invert

bones1 = get_bone_structure(wmb1)
bones2 = get_bone_structure(wmb2)

#works but for the arms
#F..ing subtree isomorphism problem
#mapping = get_bone_mapping(bones2, bones1)

common_mapping = YAML::load_file("Bayonetta2_Bayonetta_common_bones_mapping.yaml")
#common_bones = YAML::load_file("Bayonetta2_common_bones.yaml")
#mapping = YAML::load_file("Bayo2_pl0010_Bayo_pl0010_bone_mapping.yaml")

mapping = {}

tt2.each { |key, val|
  mapping[key] = tt1[common_mapping[val]]
}
mapping = mapping.to_a.sort { |e1, e2| e1.first <=> e2.first }.to_h
missing_bones = mapping.select { |k,v| v.nil? }.collect { |k,v| bones2[k] }

p mapping
#missing_mapping = get_bone_mapping(missing_bones, bones1)
#p missing_mapping
#mapping.update(missing_mapping)
#p mapping

#// should have worked, maybe the incomplete translate table is problematic... works in noesis.
#
mapping[-1] = -1
missing_bones = mapping.select { |k,v| v.nil? }
new_bone_index = wmb1.header.num_bones
new_bone_indexes = []
missing_bones.each { |bi,_|
  mapping[bi] = new_bone_index
  new_bone_indexes.push(new_bone_index)
  wmb1.bone_hierarchy.push( mapping[wmb2.bone_hierarchy[bi]] )
  wmb1.bone_relative_positions.push( wmb2.bone_relative_positions[bi] )
  wmb1.bone_positions.push( wmb2.bone_positions[bi] )
  #maybe update translate table, need a safe range of indexes 1000+ maybe
  wmb1.bone_infos.push( -1 ) if wmb1.header.offset_bone_infos > 0x0
  wmb1.bone_flags.push( 5 ) if wmb1.header.offset_bone_flags > 0x0
  new_bone_index += 1
}
wmb1.header.num_bones = new_bone_index
missing_bones_count = missing_bones.length
raise "Too many bones to add!" if missing_bones_count > 0x100
missing_bones_slots = align(missing_bones_count, 0x10)/0x10
(align(missing_bones_count, 0x10) - missing_bones_count).times {
  new_bone_indexes.push(0xfff)
}
new_bone_indexes.each_slice(0x10) { |s|
  tt = WMBFile::BoneIndexTranslateTable::new
  tt.offsets = s
  wmb1.bone_index_translate_table.third_levels.push tt
}
if wmb1.bone_index_translate_table.second_levels.last.offsets[-missing_bones_slots..-1].uniq == [-1]
  last_offset = wmb1.bone_index_translate_table.second_levels.last.offsets.reverse.find { |o| o != -1 }
else
  last_offset = wmb1.bone_index_translate_table.offsets.reverse.find { |o| o != -1 }
  last_index = wmb1.bone_index_translate_table.offsets.index(last_offset) + 1
  raise "No room available in translate table!" if last_index >= 0x10
  last_offset += 0x10
  wmb1.bone_index_translate_table.offsets[last_index] = last_offset
  wmb1.bone_index_translate_table.second_levels.each { |l|
    l.offsets.collect! { |o|
      if o != -1
        last_offset += 0x10
      else
        o
      end
    }
  }
  tt = WMBFile::BoneIndexTranslateTable::new
  tt.offsets = [-1]*0x10
  wmb1.bone_index_translate_table.second_levels.push(tt)
end
(-missing_bones_slots..-1).each { |i|
  last_offset += 0x10
  wmb1.bone_index_translate_table.second_levels.last.offsets[i] = last_offset
}


p mapping
#mapping.each_with_index { |i, j|
#  p = bones2[j]
#  q = bones1[i]
#  puts "#{j} -> #{i} : #{p.distance(q)}"
#}

apply_mapping(mapping, wmb2.meshes)


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

last_offset = wmb1.header.offset_vertexes_ex_data = wmb1.header.offset_vertexes + size_vertexes
last_offset += (num_vertex2 + num_vertex1) * wmb1.header.vertex_ex_data_size * 4
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

old_offset = wmb1.header.offset_materials_offsets
wmb1.header.offset_materials_offsets = align(last_offset, 0x20)
delta = wmb1.header.offset_materials_offsets - old_offset

wmb1.header.offset_materials += delta
wmb1.header.offset_meshes_offsets += delta
wmb1.header.offset_meshes += delta

mesh_offset = align(wmb1.meshes_offsets.last + wmb1.meshes.last.size, 0x20)
new_meshes_offset = wmb2.meshes_offsets.collect { |e|
  e + mesh_offset
}

wmb1.header.num_meshes += wmb2.header.num_meshes
wmb2.meshes.each { |m|
  m.batches.each { |b|
    b.header.vertex_start += num_vertex1
    b.header.vertex_end += num_vertex1
    b.header.vertex_offset += num_vertex1
  }
}
wmb1.meshes +=  wmb2.meshes
wmb1.meshes_offsets += new_meshes_offset

wmb1.header.offset_meshes = align(wmb1.header.offset_meshes_offsets + 4*wmb1.header.num_meshes, 0x20)



wmb1.dump("wmb_output/"+File.basename(input_file1))
