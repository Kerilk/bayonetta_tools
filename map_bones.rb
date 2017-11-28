#!ruby
require 'ffi'
require 'win32-mmap'
require 'float-formats'
include Win32

class WMBHeader < FFI::Struct
  layout :id,                               [:char, 4],
         :unknownA,                          :int,
         :unknownB,                          :int,
         :num_vertexes,                      :int,
         :vertex_ex_data_size,               :char,
         :vertex_ex_data,                    :char,
         :unknownE,                          :short,
         :unknownF,                          :int,
         :offset_vertexes,                   :uint,
         :offset_vertexes_ex_data,           :uint,
         :unknownG,                         [:int, 4],
         :num_bones,                         :int,
         :offset_bone_hierarchy,             :uint,
         :offset_bone_relative_position,     :uint,
         :offset_bone_position,              :uint,
         :offset_bone_index_translate_table, :uint,
         :num_materials,                     :int,
         :offset_materials_offsets,          :uint,
         :offset_materials,                  :uint,
         :num_meshes,                        :int,
         :offset_meshes_offsets,             :uint,
         :offset_meshes,                     :uint,
         :unknownK,                          :int,
         :unknownL,                          :int,
         :offset_unknownJ,                   :uint,
         :offset_bone_infos,                 :uint,
         :offset_bone_flags,                 :uint,
         :ex_mat_info,                      [:int, 4]
end

class Vector < FFI::Struct
  layout :x, :float,
         :y, :float,
         :z, :float
end

class Bone
  attr_accessor :parent
  attr_accessor :index
  attr_accessor :x, :y, :z
  def initialize( x, y, z)
    @x = x
    @y = y
    @z = z
  end

  def depth
    if parent then
      return parent.depth + 1
    else
      return 0
    end
  end

  def to_s
    "#{@index}#{@parent ? " (#{@parent.index})" : ""}: #{@x}, #{@y}, #{@z}, d: #{depth}"
  end

  def inspect
    to_s
  end

  def distance(other)
    d = (@x - other.x)**2 + (@y - other.y)**2 + (@z - other.z)**2
    d = Math::sqrt(d)
    dd = (depth - other.depth).abs
    [d, dd]
  end

end

def load_bone_positions( f )
  ext_name = File.extname(f)

  raise "Invalid file (#{f})!" unless ext_name == ".wmb" || ext_name == ".wmb"

  map = MMap.new(:file => f)
  case map.read_string(4)
  when "WMB\0"
    order = :little
  when "\0BMW"
    order = :big
  else
    raise "invalid model file #{f}"
  end
  puts order
  map_address = map.address
  header = WMBHeader::new(FFI::Pointer::new(map_address))
  header = header.order(order)

  num_bones = header[:num_bones]
  puts num_bones
  p = FFI::Pointer::new(map_address + header[:offset_bone_position])
  bones = num_bones.times.collect { |i|
    pos = 3.times.collect { |j|
      s = (p+(i*3*4+j*4)).read_string(4)
      if order == :big then
        Flt::IEEE_binary32_BE::from_bytes(s).to(Float)
      else
        Flt::IEEE_binary32::from_bytes(s).to(Float)
      end
    }
    Bone::new(pos[0], pos[1], pos[2])
  }

  p = FFI::Pointer::new(map_address + header[:offset_bone_hierarchy]).order(order)
  hierarchy = p.read_array_of_short(header[:num_bones])
  bones.each_with_index { |b, i|
    p = hierarchy[i]
    if p == -1 then
      b.parent = nil
    else
      b.parent = bones[p]
    end
    b.index = i
  }
  bones
end

target_pos = load_bone_positions( ARGV[0] )
input_pos = load_bone_positions( ARGV[1] )

p target_pos
p input_pos


mapping = input_pos.each.collect { |p|
  distance = [Float::INFINITY, Float::INFINITY]
  min_index = nil
  target_pos.each_with_index { |q, i|
    d = p.distance(q)
    if ( d[0] <= distance[0] && d[1] < distance[1] ) || d[0] < distance[0]
      distance = d
      min_index = i
    end
  }
  min_index
}

p mapping

mapping.each_with_index { |i, j|
  p = input_pos[j]
  q = target_pos[i]
  puts "#{j} -> #{i} : #{p.distance(q)}"
}
