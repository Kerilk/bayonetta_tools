require 'set'
require 'digest'
require 'yaml'
$material_db = YAML::load_file(File.join( File.dirname(__FILE__), 'material_database.yaml'))

module Bayonetta

  class UByteList < DataConverter
    register_field :data, :L

    def self.is_bayo2?(parent)
      if parent.__parent.respond_to?(:is_bayo2?)
        return parent.__parent.is_bayo2?
      elsif parent.__parent.__parent.respond_to?(:is_bayo2?)
        return parent.__parent.__parent.is_bayo2?
      end
      raise "Cannot determine if Bayo2 or not!"
    end

    def self.inherited(subclass)
      subclass.instance_variable_set(:@fields, @fields.dup)
    end

    def self.convert(input, output, input_big, output_big, parent, index)
      h = self::new
      if is_bayo2?(parent) && input_big
        h.convert(input, output, false, output_big, parent, index)
      else
        h.convert(input, output, input_big, output_big, parent, index)
      end
      h
    end

    def self.load(input, input_big, parent, index)
      h = self::new
      if is_bayo2?(parent) && input_big
        h.load(input, false, parent, index)
      else
        h.load(input, input_big, parent, index)
      end
      h
    end

    def dump(output, output_big, parent = nil, index = nil)
      if self.class.is_bayo2?(parent) && output_big
        set_dump_type(output, false, parent, index)
      else
        set_dump_type(output, output_big, parent, index)
      end
      dump_fields
      unset_dump_type
      self
    end

    def initialize
      @data = 0
    end

  end

  class Color < UByteList

    def r
      @data & 0xff
    end

    def g
      (@data >> 8) & 0xff
    end

    def b
      (@data >> 16) & 0xff
    end

    def a
      (@data >> 24) & 0xff
    end

    def r=(v)
      @data = (@data & 0xffffff00) | (v & 0xff)
      v & 0xff
    end

    def g=(v)
      @data = (@data & 0xffff00ff) | ((v & 0xff)<<8)
      v & 0xff
    end

    def b=(v)
      @data = (@data & 0xff00ffff) | ((v & 0xff)<<16)
      v & 0xff
    end

    def a=(v)
      @data = (@data & 0x00ffffff) | ((v & 0xff)<<24)
      v & 0xff
    end

  end

  module VectorAccessor
    def [](i)
      case i
      when 0
        self.x
      when 1
        self.y
      when 2
        self.z
      else
        "Invalid index #{i} for a vector access!"
      end
    end

    def []=(i,v)
      case i
      when 0
        self.x = v
      when 1
        self.y = v
      when 2
        self.z = v
      else
        "Invalid index #{i} for a vector access!"
      end
    end

  end

  class Tangents < UByteList
    include VectorAccessor

    def clamp(v, max, min)
      if v > max
        v = max
      elsif v < min
        v = min
      end
      v
    end

    def x
      ((@data & 0xff) - 127.0)/127.0
    end

    def y
(((@data >> 8) & 0xff) - 127.0)/127.0
    end

    def z
      (((@data >> 16) & 0xff) -127.0)/127.0
    end

    def s
      (((@data >> 24) & 0xff) -127.0)/127.0
    end

    def x=(v)
      v2 = clamp((v*127.0+127.0).round, 255, 0)
      @data = (@data & 0xffffff00) | v2
      v
    end

    def y=(v)
      v2 = clamp((v*127.0+127.0).round, 255, 0)
      @data = (@data & 0xffff00ff) | (v2 << 8)
      v
    end

    def z=(v)
      v2 = clamp((v*127.0+127.0).round, 255, 0)
      @data = (@data & 0xff00ffff) | (v2 << 16)
      v
    end

    def s=(v)
      v2 = clamp((v*127.0+127.0).round, 255, 0)
      @data = (@data & 0x00ffffff) | (v2 << 24)
      v
    end

    def normalize(fx, fy, fz)
      nrm = Math::sqrt(fx*fx+fy*fy+fz*fz)
      return [0.0, 0.0, 0.0] if nrm == 0.0
      [fx/nrm, fy/nrm, fz/nrm]
    end

    def set(x, y, z, s = nil)
      x, y, z = normalize(x, y, z)
      self.x = x
      self.y = y
      self.z = z
      self.s = s if s
      self
    end

  end

  class Mapping < DataConverter
    register_field :data, :S, count: 2

    def u
      LibBin::half_from_string([@data[0]].pack("S"), "S")
    end

    def v
      LibBin::half_from_string([@data[1]].pack("S"), "S")
    end

    def u=(val)
      s = LibBin::half_to_string(val, "S")
      @data[0] = s.unpack("s").first
      val
    end

    def v=(val)
      s = LibBin::half_to_string(val, "S")
      @data[1] = s.unpack("s").first
      val
    end

    def initialize
      @data = [0, 0]
    end

  end

  class FloatMapping < DataConverter
    register_field :u, :F
    register_field :v, :F
  end

  class FloatNormal < DataConverter
    include VectorAccessor
    register_field :x, :F
    register_field :y, :F
    register_field :z, :F
  end

  class HalfNormal < DataConverter
    include VectorAccessor
    register_field :data, :S, count: 4

    def x
      LibBin::half_from_string([@data[0]].pack("S"), "S")
    end

    def y
      LibBin::half_from_string([@data[1]].pack("S"), "S")
    end

    def z
      LibBin::half_from_string([@data[2]].pack("S"), "S")
    end

    def x=(v)
      s = LibBin::half_to_string(v, "S")
      @data[0] = s.unpack("s").first
      v
    end

    def y=(v)
      s = LibBin::half_to_string(v, "S")
      @data[1] = s.unpack("s").first
      v
    end

    def z=(v)
      s = LibBin::half_to_string(v, "S")
      @data[2] = s.unpack("s").first
      v
    end

    def initialize
      @data = [0, 0, 0, 0]
    end

  end

  class Normal < DataConverter
    include VectorAccessor
    attr_accessor :normal

    def initialize
      @normal = [0.0, 0.0, 0.0]
      @normal_big_orig = nil
      @normal_small_orig = nil
    end

    def x
      @normal[0]
    end

    def y
      @normal[1]
    end

    def z
      @normal[2]
    end

    def x=(v)
      @normal_big_orig = nil
      @normal_small_orig = nil
      @normal[0] = v
    end

    def y=(v)
      @normal_big_orig = nil
      @normal_small_orig = nil
      @normal[1] = v
    end

    def z=(v)
      @normal_big_orig = nil
      @normal_small_orig = nil
      @normal[2] = v
    end

    def size(position, parent, index)
      4
    end

    def normalize(fx, fy, fz)
      nrm = Math::sqrt(fx*fx+fy*fy+fz*fz)
      return [0.0, 0.0, 0.0] if nrm == 0.0
      [fx/nrm, fy/nrm, fz/nrm]
    end

    def decode_big_normal(vs)
      v = vs.unpack("L>").first
      nx = v & ((1<<10)-1)
      ny = (v >> 10) & ((1<<10)-1)
      nz = (v >> 20) & ((1<<10)-1)
      sx = nx & (1<<9)
      sy = ny & (1<<9)
      sz = nz & (1<<9)
      if sx
        nx ^= sx
        nx = -(sx-nx)
      end
      if sy
        ny ^= sy
        ny = -(sy-ny)
      end
      if sz
        nz ^= sz
        nz = -(sz-nz)
      end

      mag = ((1<<9)-1).to_f
      fx = nx.to_f/mag
      fy = ny.to_f/mag
      fz = nz.to_f/mag

      normalize(fx, fy, fz)
    end

    def decode_small_normal(v)
      n = v.unpack("c4")
      nx = n[3]
      ny = n[2]
      nz = n[1]
      mag = 127.0
      fx = nx.to_f/mag
      fy = ny.to_f/mag
      fz = nz.to_f/mag

      normalize(fx, fy, fz)
    end

    def clamp(v, max, min)
      if v > max
        v = max
      elsif v < min
        v = min
      end
      v
    end

    def encode_small_normal(normal)
      fx = normal[0]
      fy = normal[1]
      fz = normal[2]
      nx = (fx*127.0).to_i
      ny = (fy*127.0).to_i
      nz = (fz*127.0).to_i
      nx = clamp(nx, 127, -128)
      ny = clamp(ny, 127, -128)
      nz = clamp(nz, 127, -128)
      [0, nz, ny, nx].pack("c4")
    end

    def encode_big_normal(normal)
      fx = normal[0]
      fy = normal[1]
      fz = normal[2]
      mag = (1<<9)-1
      nx = (fx*(mag).to_f).to_i
      ny = (fy*(mag).to_f).to_i
      nz = (fz*(mag).to_f).to_i
      nx = clamp(nx, mag, -1-mag)
      ny = clamp(ny, mag, -1-mag)
      nz = clamp(nz, mag, -1-mag)
      mask = (1<<10)-1
      v = 0
      v |= nz & mask
      v <<= 10
      v |= ny & mask
      v <<= 10
      v |= nx & mask
      [v].pack("L>")
    end

    def load_normal
      s = @input.read(4)
      if @input_big
        @normal_big_orig = s
        @normal_small_orig = nil
        @normal = decode_big_normal(s)
      else
        @normal_small_orig = s
        @normal_big_orig = nil
        @normal = decode_small_normal(s)
      end
    end

    def dump_normal
      if @output_big
        s2 = (@normal_big_orig ? @normal_big_orig : encode_big_normal(@normal))
      else
        s2 = (@normal_small_orig ? @normal_small_orig : encode_small_normal(@normal))
      end
      @output.write(s2)
    end

    def convert_normal
      load_normal
      dump_normal
    end

    def convert_fields
      convert_normal
    end

    def load_fields
      load_normal
    end

    def dump_fields
      dump_normal
    end

  end

  class Position < DataConverter
    include VectorAccessor
    register_field :x, :F
    register_field :y, :F
    register_field :z, :F

    def -(other)
      b = Position::new
      b.x = @x - other.x
      b.y = @y - other.y
      b.z = @z - other.z
      b
    end

    def -@
      b = Position::new
      b.x = -@x
      b.y = -@y
      b.z = -@z
      b
    end

    def +(other)
      b = Position::new
      b.x = @x + other.x
      b.y = @y + other.y
      b.z = @z + other.z
      b
    end

    def *(scal)
      b = Position::new
      b.x = @x*scal
      b.y = @y*scal
      b.z = @z*scal
      b
    end

    def to_yaml_properties
      [:@x, :@y, :@z]
    end

    def to_s
      "<#{@x}, #{@y}, #{@z}>"
    end

  end

  class BoneInfos < DataConverter
    register_field :indexes, UByteList
    register_field :weights, UByteList

    def initialize
      @indexes = UByteList::new
      @weights = UByteList::new
    end

    def get_indexes_and_weights
      res = []
      4.times { |i|
        bi = (@indexes.data >> (i*8)) & 0xff
        bw = (@weights.data >> (i*8)) & 0xff
        res.push [bi, bw] if bw > 0
      }
      res
    end

    def get_indexes
      get_indexes_and_weights.collect { |bi, _| bi }
    end

    def get_weights
      get_indexes_and_weights.collect { |_, bw| bw }
    end

    def remap_indexes(map)
      new_bone_info = get_indexes_and_weights.collect { |bi, bw| [map[bi], bw] }
      set_indexes_and_weights(new_bone_info)
      self
    end

    def set_indexes_and_weights(bone_info)
      raise "Too many bone information #{bone_info.inspect}!" if bone_info.length > 4
      @indexes.data = 0
      @weights.data = 0
      bone_info.each_with_index { |(bi, bw), i|
        raise "Invalid bone index #{bi}!" if bi > 255 || bi < 0
        @indexes.data |= ( bi << (i*8) )
        bw = 0 if bw < 0
        bw = 255 if bw > 255
        @weights.data |= (bw << (i*8) )
      }
      self
    end

  end

  class BoneIndexTranslateTable < DataConverter
    register_field :offsets, :s, count: 16
    #attr_accessor :second_levels
    #attr_accessor :third_levels
    attr_reader :table

    def table=(t)
      @table = t
      encode
      t
    end

    def size(position = 0, parent = nil, index = nil)
      sz = super()
      if @second_levels
        @second_levels.each { |e|
          sz += e.size(position, parent, index)
        }
      end
      if @third_levels
        @third_levels.each { |e|
          sz += e.size(position, parent, index)
        }
      end
      sz
    end

    def convert(input, output, input_big, output_big, parent, index, level = 1)
      set_convert_type(input, output, input_big, output_big, parent, index)
      convert_fields
      if level == 1
        @second_levels = []
        @offsets.each { |o|
          if o != -1
            t = self.class::new
            t.convert(input, output, input_big, output_big, self, nil, level+1)
            @second_levels.push t
          end
        }
        @third_levels = []
        @second_levels.each { |l|
          l.offsets.each { |o|
            if o != -1
              t = self.class::new
              t.convert(input, output, input_big, output_big, self, nil, level+2)
              @third_levels.push t
            end
          }
        }
        decode
      else
        @second_levels = nil
        @third_levels = nil
      end
      unset_convert_type
    end

    def load(input, input_big, parent, index, level = 1)
      set_load_type(input, input_big, parent, index)
      load_fields
      if level == 1
        @second_levels = []
        @offsets.each { |o|
          if o != -1
            t = self.class::new
            t.load(input, input_big, self, nil, level+1)
            @second_levels.push t
          end
        }
        @third_levels = []
        @second_levels.each { |l|
          l.offsets.each { |o|
            if o != -1
              t = self.class::new
              t.load(input, input_big, self, nil, level+2)
              @third_levels.push t
            end
          }
        }
        decode
      else
        @second_levels = nil
        @third_levels = nil
      end
      unset_load_type
    end

    def decode
      t = (@offsets+@second_levels.collect(&:offsets)+@third_levels.collect(&:offsets)).flatten
      @table = (0x0..0xfff).each.collect { |i|
        index = t[(i & 0xf00)>>8]
        next if index == -1
        index = t[index + ((i & 0xf0)>>4)]
        next if index == -1
        index = t[index + (i & 0xf)]
        next if index == 0xfff
        [i, index]
      }.compact.to_h
    end
    private :decode

    def encode
      keys = @table.keys.sort
      first_table = 16.times.collect { |i|
        lower = i*0x100
        upper = (i+1)*0x100
        keys.select { |k|  k >= lower && k < upper }
      }
      off = 0x0
      @offsets = first_table.collect { |e| e == [] ? -1 : (off += 0x10) }

      second_table = first_table.select { |e| e != [] }.collect { |e|
        16.times.collect { |i|
          lower = i*0x10
          upper = (i+1)*0x10
          e.select { |k|  (k&0xff) >= lower && (k&0xff) < upper }
        }
      }
      @second_levels = second_table.collect { |st|
        tab = BoneIndexTranslateTable::new
        tab.offsets = st.collect { |e| e == [] ? -1 : (off += 0x10) }
        tab
      }
      @third_levels = []
      second_table.each { |e|
        e.select { |ee| ee != [] }.each { |ee|
          tab = BoneIndexTranslateTable::new
          tab.offsets = [0xfff]*16
          ee.each { |k|
            tab.offsets[k&0xf] = @table[k]
          }
          @third_levels.push tab
        }
      }
      self
    end
    private :encode

    def dump(output, output_big, parent, index, level = 1)
      set_dump_type(output, output_big, parent, index)
      encode if level == 1
      dump_fields
      if @second_levels
        @second_levels.each { |e|
          e.dump(output, output_big, self, nil, level+1)
        }
      end
      if @third_levels
        @third_levels.each { |e|
          e.dump(output, output_big, self, nil, level+2)
        }
      end
      unset_dump_type
    end

  end

  VERTEX_FIELDS = {
    position_t: [ Position, 12 ],
    mapping_t: [ Mapping, 4 ],
    normal_t: [ Normal, 4 ],
    tangents_t: [ Tangents, 4 ],
    bone_infos_t: [ BoneInfos, 8],
    color_t: [ Color, 4],
    fnormal_t: [ FloatNormal, 12 ],
    hnormal_t: [ HalfNormal, 8 ],
    fmapping_t: [ FloatMapping, 8]
  }

  class WMBFile < DataConverter
    include Alignment

    VERTEX_TYPES = {}
    VERTEX_TYPES.update( YAML::load_file(File.join( File.dirname(__FILE__), 'vertex_types.yaml')) )
    VERTEX_TYPES.update( YAML::load_file(File.join( File.dirname(__FILE__), 'vertex_types2.yaml')) )

    class UnknownStruct < DataConverter
      register_field :u_a1, :C, count: 4
      register_field :u_b1, :L
      register_field :u_c1, :s, count: 4
      register_field :u_a2, :C, count: 4
      register_field :u_b2, :L
      register_field :u_c2, :s, count: 4
      register_field :u_a3, :C, count: 4
      register_field :u_b3, :L
    end

    class Material < DataConverter
      register_field :type, :s
      register_field :flag, :S
      register_field :material_data, :L,
        count: '(..\materials_offsets[__index+1] ? ..\materials_offsets[__index+1] - ..\materials_offsets[__index] - 4 : ..\header\offset_meshes_offsets - __position - 4)/4'

      def size(position = 0, parent = nil, index = nil)
        return 2 + 2 + @material_data.length * 4
      end
    end

    class Bayo1Material
      attr_reader :type
      attr_reader :flag
      attr_reader :samplers
      attr_reader :parameters

      def initialize(m)
        @type = m.type
        @flag = m.flag
        @layout = $material_db[@type][:layout]
        @samplers = {}
        @parameters = {}
        field_count = 0
        @layout.each { |name, t|
          if t == "sampler2D_t" || t == "samplerCUBE_t"
            @samplers[name] = m.material_data[field_count]
            field_count += 1
          else
            @parameters[name] = m.material_data[field_count...(field_count+4)].pack("L4").unpack("F4")
            field_count += 4
          end
        }
      end

    end

    class BatchHeader < DataConverter
      register_field :batch_id, :s #Bayo 2
      register_field :mesh_id, :s
      register_field :u_b, :S
      register_field :ex_mat_id, :s
      register_field :material_id, :C
      register_field :u_d, :c
      register_field :u_e1, :C
      register_field :u_e2, :C
      register_field :vertex_start, :L
      register_field :vertex_end, :L
      register_field :primitive_type, :l
      register_field :offset_indices, :L
      register_field :num_indices, :l
      register_field :vertex_offset, :l
      register_field :u_f, :l, count: 7

      def initialize
        @batch_id = 0
        @mesh_id = 0
        @u_b = 0x8001
        @ex_mat_id = 0
        @material_id = 0
        @u_d = 1
        @u_e1 = 0
        @u_e2 = 0
        @vertex_start = 0
        @vertex_end = 0
        @primitive_type = 4
        @offset_indices = 0x100
        @num_indices = 0
        @vertex_offset = 0
        @u_f = [0]*7
      end
    end

    class Batch < DataConverter
      register_field :header, BatchHeader
      register_field :num_bone_ref, :l, condition: '(header\u_b & 0x8000) != 0 || ..\..\is_bayo2?'
      register_field :bone_refs, :C, count: 'num_bone_ref', condition: '(header\u_b & 0x8000) != 0 || ..\..\is_bayo2?'
      register_field :unknown, :F, count: 4, condition: '(header\u_b & 0x8000) == 0 && !(..\..\is_bayo2?)'
      register_field :indices, :S, count: 'header\num_indices', offset: '__position + header\offset_indices'

      def initialize
        @header = BatchHeader::new
        @num_bone_ref = 0
        @bone_refs = []
        @indices = []
      end

      def duplicate(positions, vertexes, vertexes_ex)
        b = Batch::new
        if (header.u_b & 0x8000) != 0 || (header.u_b & 0x80)
          b.header = @header.dup
          b.num_bone_ref = @num_bone_ref
          b.bone_refs = @bone_refs.dup
        else
          b.unknown = @unknown
        end
        l = vertexes.length
        old_indices_map = vertex_indices.uniq.sort.each_with_index.collect { |vi, i| [vi, l + i] }.to_h
        old_indices_map.each { |vi, nvi| positions[nvi] = positions[vi] } if positions
        old_indices_map.each { |vi, nvi| vertexes[nvi] = vertexes[vi] }
        old_indices_map.each { |vi, nvi| vertexes_ex[nvi] = vertexes_ex[vi] } if vertexes_ex
        b.indices = vertex_indices.collect { |vi| old_indices_map[vi] }
        b.recompute_from_absolute_indices
        b
      end

      def recompute_from_absolute_indices
        @header.num_indices = @indices.length
        unless @header.num_indices == 0
          sorted_indices = @indices.sort.uniq
          @header.vertex_start = sorted_indices.first
          @header.vertex_end = sorted_indices.last + 1
          if sorted_indices.last > 0xffff
            offset = @header.vertex_offset = @header.vertex_start
            @indices.collect! { |i| i - offset }
          else
            @header.vertex_offset = 0
          end
        end
        self
      end

      def size(position = 0, parent = nil, index = nil)
        sz = @header.offset_indices
        sz += @header.num_indices * 2
        sz
      end

      def triangles
        inds = @indices.collect{ |i| i + @header.vertex_offset }
        if @header.primitive_type == 4
          inds.each_slice(3).to_a
        else
          inds.each_cons(3).each_with_index.collect do |(v0, v1, v2), i|
            if i.even?
              [v0, v1, v2]
            else
              [v1, v0, v2]
            end
          end.select { |t| t.uniq.length == 3 }
        end
      end

      def set_triangles(trs)
        @header.primitive_type = 4
        @indices = trs.flatten
        recompute_from_absolute_indices
        @header.num_indices = @indices.length
        self
      end

      def filter_vertexes(vertexes)
        vertex_map = vertexes.collect { |i| [i, true] }.to_h
        trs = triangles
        new_trs = trs.select { |tr| vertex_map.include?(tr[0]) && vertex_map.include?(tr[1]) && vertex_map.include?(tr[2]) }
        set_triangles(new_trs)
      end

      def vertex_indices
        indices.collect { |i| i + @header.vertex_offset }
      end

      def cleanup_bone_refs(vertexes)
        if (header.u_b & 0x8000) != 0 || (header.u_b & 0x80)
          bone_refs_map = @bone_refs.each_with_index.collect { |b, i| [i, b] }.to_h
          used_bone_refs_indexes = vertex_indices.collect { |vi| vertexes[vi].bone_infos.get_indexes }.flatten.uniq
          new_bone_refs_list = used_bone_refs_indexes.collect{ |i| bone_refs_map[i] }.uniq.sort
          new_bone_refs_reverse_map = new_bone_refs_list.each_with_index.collect { |b, i| [b, i] }.to_h
          translation_map = used_bone_refs_indexes.collect { |ri|
            [ri, new_bone_refs_reverse_map[bone_refs_map[ri]]]
          }.to_h
          vertex_indices.uniq.sort.each { |vi| vertexes[vi].bone_infos.remap_indexes(translation_map) }
          @bone_refs = new_bone_refs_list
          @num_bone_ref = @bone_refs.length
        end
        self
      end

      def add_ancestors_bone_refs(vertexes, bones)
        if (header.u_b & 0x8000) != 0 || (header.u_b & 0x80)
          bone_refs_map = @bone_refs.each_with_index.collect { |b, i| [i, b] }.to_h
          used_bone_refs_indexes = vertex_indices.collect { |vi| vertexes[vi].bone_infos.get_indexes }.flatten.uniq
          new_bone_refs_list = used_bone_refs_indexes.collect{ |i| bone_refs_map[i] }.uniq.sort
          new_bone_refs_set = Set::new(new_bone_refs_list)
          new_bone_refs_list.each { |bi|
            new_bone_refs_set.merge(bones[bi].parents.collect(&:index))
          }
          new_bone_refs_list = new_bone_refs_set.to_a.sort
          new_bone_refs_reverse_map = new_bone_refs_list.each_with_index.collect { |b, i| [b, i] }.to_h
          translation_map = used_bone_refs_indexes.collect { |ri|
            [ri, new_bone_refs_reverse_map[bone_refs_map[ri]]]
          }.to_h
          vertex_indices.uniq.sort.each { |vi| vertexes[vi].bone_infos.remap_indexes(translation_map) }
          @bone_refs = new_bone_refs_list
          @num_bone_ref = @bone_refs.length
        end
      end

      def add_previous_bone_refs(vertexes, bones)
        if (header.u_b & 0x8000) != 0 || (header.u_b & 0x80)
          bone_refs_map = @bone_refs.each_with_index.collect { |b, i| [i, b] }.to_h
          used_bone_refs_indexes = vertex_indices.collect { |vi| vertexes[vi].bone_infos.get_indexes }.flatten.uniq
          last_bone = used_bone_refs_indexes.collect{ |i| bone_refs_map[i] }.uniq.max
          new_bone_refs_list = (0..last_bone).to_a
          new_bone_refs_reverse_map = new_bone_refs_list.each_with_index.collect { |b, i| [b, i] }.to_h
          translation_map = used_bone_refs_indexes.collect { |ri|
            [ri, new_bone_refs_reverse_map[bone_refs_map[ri]]]
          }.to_h
          vertex_indices.uniq.sort.each { |vi| vertexes[vi].bone_infos.remap_indexes(translation_map) }
          @bone_refs = new_bone_refs_list
          @num_bone_ref = @bone_refs.length
        end
      end

    end

    class MeshHeader < DataConverter
      register_field :id, :s
      register_field :num_batch, :s
      register_field :u_a1, :s
      register_field :u_a2, :s
      register_field :offset_batch_offsets, :L
      register_field :u_b, :L
      register_field :u_c, :l, count: 4
      string         :name, 32
      register_field :mat, :F, count: 12

      def initialize
        @id = 0
        @num_batch = 0
        @u_a1 = 0
        @u_a2 = 1
        @offset_batch_offsets = 128
        @u_b = 0x80000000
        @u_c = [0]*4
        @name = [0]*32
        @mat = [0.0, 0.98, -0.42, 1.64, 1.10, 2.08,
                0.1, -1.10, -0.12, -0.95, 0.0, 0.0]
      end
    end

    class Mesh < DataConverter
      register_field :header, MeshHeader
      register_field :batch_offsets, :L, count: 'header\num_batch',
                     offset: '__position + header\offset_batch_offsets'
      register_field :batches, Batch, count: 'header\num_batch', sequence: true,
                     offset: '__position + header\offset_batch_offsets + batch_offsets[__iterator]'

      def initialize
        @header = MeshHeader::new
        @batch_offsets = []
        @batches = []
      end

      def size(position = 0, parent = nil, index = nil)
        sz = @header.offset_batch_offsets
        sz += @header.num_batch * 4
        sz = align(sz, 0x20)
        @header.num_batch.times { |i|
           sz += @batches[i].size
           sz = align(sz, 0x20)
        }
        sz
      end

      def recompute_layout
        @header.num_batch = @batches.length
        off = @header.num_batch * 4
        @batch_offsets = []
        @header.num_batch.times { |j|
          off = align(off, 0x20)
          @batch_offsets.push off
          off += @batches[j].size
        }
      end

      def duplicate(positions, vertexes, vertexes_ex)
        m = Mesh::new
        m.header = @header
        m.batch_offsets = @batch_offsets
        m.batches = @batches.collect { |b| b.duplicate(positions, vertexes, vertexes_ex) }
        m
      end

    end

    class ShaderName < DataConverter
      register_field :name, :c, count: 16
    end

    class TexInfo < DataConverter
      register_field :id, :L
      register_field :info, :l
    end

    class TexInfos < DataConverter
      register_field :num_tex_infos, :l
      register_field :tex_infos, TexInfo, count: 'num_tex_infos'
    end

    class WMBFileHeader < DataConverter
      register_field :id, :L
      register_field :u_a, :l
      register_field :u_b, :l
      register_field :num_vertexes, :l
      register_field :vertex_ex_data_size, :c
      register_field :vertex_ex_data, :c
      register_field :u_e, :s
      register_field :offset_positions, :l
      register_field :offset_vertexes, :L
      register_field :offset_vertexes_ex_data, :L
      register_field :u_g, :l, count: 4
      register_field :num_bones, :l
      register_field :offset_bone_hierarchy, :L
      register_field :offset_bone_relative_position, :L
      register_field :offset_bone_position, :L
      register_field :offset_bone_index_translate_table, :L
      register_field :num_materials, :l
      register_field :offset_materials_offsets, :L
      register_field :offset_materials, :L
      register_field :num_meshes, :l
      register_field :offset_meshes_offsets, :L
      register_field :offset_meshes, :L
      register_field :u_k, :l
      register_field :u_l, :l
      register_field :offset_u_j, :L
      register_field :offset_bone_symmetries, :L
      register_field :offset_bone_flags, :L
      register_field :offset_shader_names, :L
      register_field :offset_tex_infos, :L
      register_field :u_m, :L
      register_field :u_n, :L
    end

    register_field :header, WMBFileHeader
    register_field :positions, Position, count: 'header\num_vertexes', offset: 'header\offset_positions'
    register_field :vertexes, 'get_vertex_types[0]', count: 'header\num_vertexes', offset: 'header\offset_vertexes'
    register_field :vertexes_ex_data, 'get_vertex_types[1]', count: 'header\num_vertexes',
                   offset: 'header\offset_vertexes_ex_data'
    register_field :bone_hierarchy, :s, count: 'header\num_bones', offset: 'header\offset_bone_hierarchy'
    register_field :bone_relative_positions, Position, count: 'header\num_bones',
                   offset: 'header\offset_bone_relative_position'
    register_field :bone_positions, Position, count: 'header\num_bones', offset: 'header\offset_bone_position'
    register_field :bone_index_translate_table, BoneIndexTranslateTable,
                   offset: 'header\offset_bone_index_translate_table'
    register_field :u_j, UnknownStruct, offset: 'header\offset_u_j'
    register_field :bone_symmetries, :s, count: 'header\num_bones', offset: 'header\offset_bone_symmetries'
    register_field :bone_flags, :c, count: 'header\num_bones', offset: 'header\offset_bone_flags'
    register_field :shader_names, ShaderName, count: 'header\num_materials', offset: 'header\offset_shader_names'
    register_field :tex_infos, TexInfos, offset: 'header\offset_tex_infos'
    register_field :materials_offsets, :L, count: 'header\num_materials', offset: 'header\offset_materials_offsets'
    register_field :materials, Material, count: 'header\num_materials', sequence: true,
                   offset: 'header\offset_materials + materials_offsets[__iterator]'
    register_field :meshes_offsets, :L, count: 'header\num_meshes', offset: 'header\offset_meshes_offsets'
    register_field :meshes, Mesh, count: 'header\num_meshes', sequence: true,
                   offset: 'header\offset_meshes + meshes_offsets[__iterator]'

    def get_vertex_types
      if @vertex_type
        return [@vertex_type, @vertex_ex_type]
      else
        types = VERTEX_TYPES[ [ @header.u_b, @header.vertex_ex_data_size, @header.vertex_ex_data] ]
        @vertex_type = Class::new(DataConverter)
        @vertex_size = 0
        if types[0]
          types[0].each { |name, type|
            @vertex_type.register_field(name, VERTEX_FIELDS[type][0])
            @vertex_size += VERTEX_FIELDS[type][1]
          }
        end
        @vertex_ex_type = Class::new(DataConverter)
        @vertex_ex_size = 0
        if types[1]
          types[1].each { |name, type|
            @vertex_ex_type.register_field(name, VERTEX_FIELDS[type][0])
            @vertex_ex_size += VERTEX_FIELDS[type][1]
          }
        end
        return [@vertex_type, @vertex_ex_type]
      end
    end

    def get_vertex_fields
      if @vertex_fields
        return @vertex_fields
      else
        types = VERTEX_TYPES[ [ @header.u_b, @header.vertex_ex_data_size, @header.vertex_ex_data] ]
        @vertex_fields = []
        if types[0]
          types[0].each { |name, type|
            @vertex_fields.push(name)
          }
        end
        if types[1]
          types[1].each { |name, type|
            @vertex_fields.push(name)
          }
        end
        return @vertex_fields
      end
    end

    def get_vertex_field(field, vi)
      if @vertexes[vi].respond_to?(field)
        return @vertexes[vi].send(field)
      elsif @vertexes_ex_data && @vertexes_ex_data[vi].respond_to?(field)
        return @vertexes_ex_data[vi].send(field)
      elsif field == :position && @positions
        return @positions[vi]
      else
        return nil
      end
    end

    def set_vertex_field(field, vi, val)
      if @vertexes[vi].respond_to?(field)
        return @vertexes[vi].send(:"#{field}=", val)
      elsif @vertexes_ex_data && @vertexes_ex_data[vi].respond_to?(field)
        return @vertexes_ex_data[vi].send(:"#{field}=", val)
      elsif field == :position && @positions
        return @positions[vi] = val
      else
        raise "Couldn't find field: #{field}!"
      end
    end

    def self.convert(input_name, output_name, output_big = false)
      if input_name.respond_to?(:read) && input_name.respond_to?(:seek)
        input = input_name
      else
        input = File.open(input_name, "rb")
      end
      input_big = validate_endianness(input)

      if output_name.respond_to?(:write) && output_name.respond_to?(:seek)
        output = output_name
      else
        output = File.open(output_name, "wb")
      end
      output.write("\xFB"*input.size)
      output.rewind

      wmb = self::new
      wmb.instance_variable_set(:@__was_big, input_big)
      wmb.convert(input, output, input_big, output_big)

      input.close unless input_name.respond_to?(:read) && input_name.respond_to?(:seek)
      output.close unless output_name.respond_to?(:write) && output_name.respond_to?(:seek)
      wmb
    end

    def self.load(input_name)
      if input_name.respond_to?(:read) && input_name.respond_to?(:seek)
        input = input_name
      else
        input = File.open(input_name, "rb")
      end
      if is_wmb3?(input)
        input.close unless input_name.respond_to?(:read) && input_name.respond_to?(:seek)
        return WMB3File::load(input_name)
      end
      input_big = validate_endianness(input)

      wmb = self::new
      wmb.instance_variable_set(:@__was_big, input_big)
      wmb.load(input, input_big)
      input.close unless input_name.respond_to?(:read) && input_name.respond_to?(:seek)

      wmb
    end

    def was_big?
      @__was_big
    end

    def is_bayo2?
      @header.offset_shader_names != 0 || @header.offset_tex_infos != 0
    end

    def self.is_wmb3?(input)
      input.rewind
      id = input.read(4).unpack("a4").first
      input.rewind
      return id == "WMB3".b || id == "3BMW".b
    end

    def self.validate_endianness(input)
      input.rewind
      id = input.read(4).unpack("a4").first
      case id
      when "WMB\0".b
        input_big = false
      when "\0BMW".b
        input_big = true
      else
        raise "Invalid file type #{id}!"
      end
      input.rewind
      input_big
    end

    def dump(output_name, output_big = false)
      if output_name.respond_to?(:write) && output_name.respond_to?(:seek)
        output = output_name
      else
        output = File.open(output_name, "wb")
      end
      output.rewind

      set_dump_type(output, output_big, nil, nil)
      dump_fields
      unset_dump_type

      sz = output.size
      sz = align(sz, 0x20)
      if sz > output.size
        output.seek(sz-1)
        output.write("\x00")
      end

      output.close unless output_name.respond_to?(:write) && output_name.respond_to?(:seek)
      self
    end

    def get_bone_structure
      bones = @bone_positions.collect { |p|
        Bone::new(p)
      }
      bones.each_with_index { |b, i|
        if @bone_hierarchy[i] == -1
          b.parent = nil
        else
          b.parent = bones[@bone_hierarchy[i]]
          bones[@bone_hierarchy[i]].children.push(b)
        end
        b.index = i
        b.relative_position = @bone_relative_positions[i]
        b.symmetric = @bone_symmetries[i] if @header.offset_bone_symmetries > 0x0
        b.flag = @bone_flags[i] if @header.offset_bone_flags > 0x0
      }
    end

    def recompute_relative_positions
      @bone_hierarchy.each_with_index { |b, i|
        if b != -1
          #puts "bone: #{i} parent: #{b} position: #{@bone_positions[i]} pposition: #{@bone_positions[b]}"
          @bone_relative_positions[i] = @bone_positions[i] - @bone_positions[b]
        else
          @bone_relative_positions[i] = @bone_positions[i]
        end
      }
      self
    end

    def set_bone_structure(bones)
      @bone_hierarchy = []
      @bone_relative_positions = []
      @bone_positions = []
      @bone_symmetries = [] if @header.offset_bone_symmetries > 0x0
      @bone_flags = [] if @header.offset_bone_flags > 0x0
      bones.each { |b|
        p_index = -1
        p_index = b.parent.index if b.parent
        @bone_hierarchy.push p_index
        @bone_positions.push b.position
        rel_position = b.relative_position
        unless rel_position
          if b.parent
            rel_position = b.position - b.parent.position
          else
            rel_position = b.position
          end
        end
        @bone_relative_positions.push rel_position
        @bone_symmetries.push b.symmetric if @header.offset_bone_symmetries > 0x0
        @bone_flags.push b.flag if @header.offset_bone_flags > 0x0
      }
      @header.num_bones = bones.size
      self
    end

    def scale(s)
      if @positions
        @positions.each { |p|
          p.x = p.x * s
          p.y = p.y * s
          p.z = p.z * s
        }
      end
      if @vertexes && @vertexes.first.respond_to?(:position)
        @vertexes.each { |v|
          v.position.x = v.position.x * s
          v.position.y = v.position.y * s
          v.position.z = v.position.z * s
        }
      end
      if @vertexes && @vertexes.first.respond_to?(:position2)
        @vertexes.each { |v|
          v.position2.x = v.position2.x * s
          v.position2.y = v.position2.y * s
          v.position2.z = v.position2.z * s
        }
      end
      if @vertexes_ex_data && @vertexes_ex_data.first.respond_to?(:position2)
        @vertexes_ex_data.each { |v|
          v.position2.x = v.position2.x * s
          v.position2.y = v.position2.y * s
          v.position2.z = v.position2.z * s
        }
      end
      if @bone_positions
        @bone_positions.each { |p|
          p.x = p.x * s
          p.y = p.y * s
          p.z = p.z * s
        }
        recompute_relative_positions
      end
      self
    end

    def shift(x, y, z)
      if @positions
        @positions.each { |p|
          p.x = p.x + x
          p.y = p.y + y
          p.z = p.z + z
        }
      end
      if @vertexes && @vertexes.first.respond_to?(:position)
        @vertexes.each { |v|
          v.position.x = v.position.x + x
          v.position.y = v.position.y + y
          v.position.z = v.position.z + z
        }
      end
      if @vertexes && @vertexes.first.respond_to?(:position2)
        @vertexes.each { |v|
          v.position2.x = v.position2.x + x
          v.position2.y = v.position2.y + y
          v.position2.z = v.position2.z + z
        }
      end
      if @vertexes_ex_data && @vertexes_ex_data.first.respond_to?(:position2)
        @vertexes_ex_data.each { |v|
          v.position2.x = v.position2.x + x
          v.position2.y = v.position2.y + y
          v.position2.z = v.position2.z + z
        }
      end
      if @bone_positions
        @bone_positions.each { |p|
          p.x = p.x + x
          p.y = p.y + y
          p.z = p.z + z
        }
        recompute_relative_positions
      end
      self
    end

    def rotate(*args)
      if args.length == 2
        (rx, ry, rz), center = args
      elsif args.length == 3
        rx, ry, rz = args
        center = nil
      else
        raise "Invalid arguments for rotate: #{args.inspect}!"
      end
      m = Linalg::get_rotation_matrix(rx, ry, rz, center: center)
      if @positions
        @positions.each { |p|
          r = m * Linalg::Vector::new(p.x, p.y, p.z)
          p.x = r.x
          p.y = r.y
          p.z = r.z
        }
      end
      if @vertexes && @vertexes.first.respond_to?(:position)
        @vertexes.each { |v|
          r = m * Linalg::Vector::new(v.position.x, v.position.y, v.position.z)
          v.position.x = r.x
          v.position.y = r.y
          v.position.z = r.z
        }
      end
      if @vertexes && @vertexes.first.respond_to?(:position2)
        @vertexes.each { |v|
          r = m * Linalg::Vector::new(v.position2.x, v.position2.y, v.position2.z)
          v.position2.x = r.x
          v.position2.y = r.y
          v.position2.z = r.z
        }
      end
      if @vertexes_ex_data && @vertexes_ex_data.first.respond_to?(:position2)
        @vertexes_ex_data.each { |v|
          r = m * Linalg::Vector::new(v.position2.x, v.position2.y, v.position2.z)
          v.position2.x = r.x
          v.position2.y = r.y
          v.position2.z = r.z
        }
      end
      if @bone_positions
        @bone_positions.each { |p|
          r = m * Linalg::Vector::new(p.x, p.y, p.z)
          p.x = r.x
          p.y = r.y
          p.z = r.z
        }
        recompute_relative_positions
      end
      if @vertexes
        @vertexes.each { |v|
          r = m * Linalg::Vector::new(v.normal.x, v.normal.y, v.normal.z, 0.0)
          v.normal.x = r.x
          v.normal.y = r.y
          v.normal.z = r.z
          if v.tangents.data != 0xc0c0c0ff
            r = m * Linalg::Vector::new(v.tangents.x, v.tangents.y, v.tangents.z, 0.0)
            v.tangents.x = r.x
            v.tangents.y = r.y
            v.tangents.z = r.z
          end
        }
      end
      self
    end

    def set_pose(pose, exp)
      table = @bone_index_translate_table.table
      bones = get_bone_structure
      tracks = Hash::new { |h,k| h[k] = {} }
      tracks = bones.collect { |b|
        [ b.relative_position.x,
          b.relative_position.y,
          b.relative_position.z,
          0.0, 0.0, 0.0,
          0.0,
          1.0, 1.0, 1.0,
          1.0, 1.0, 1.0 ]
      }
      pose.each { |b, ts|
        bi = table[b]
        if bi
          ts.each { |ti, v|
            tracks[bi][ti] = v
          }
        end
      }
      if exp
        exp.apply(tracks, table)
      end
      matrices = tracks.each_with_index.collect { |ts, bi|
        if @header.offset_bone_flags > 0x0
          order = @bone_flags[bi]
        else
          order = nil
        end
        m = Linalg::get_translation_matrix(*ts[0..2])
        pi = @bone_hierarchy[bi]
        if pi != -1
          parent_cumulative_scale = tracks[pi][10..12]
          m = m * Linalg::get_inverse_scaling_matrix(*parent_cumulative_scale)
          3.times { |i| ts[10+i] *= parent_cumulative_scale[i] }
        end
        3.times { |i|  ts[10+i] *= ts[7+i] }
        m = m * Linalg::get_rotation_matrix(*ts[3..5], order: order)
        m = m * Linalg::get_scaling_matrix(*ts[10..12])
      }
      multiplied_matrices = []
      inverse_bind_pose = bones.collect { |b|
        Linalg::get_translation_matrix(-1 * b.position.x, -1 * b.position.y, -1 * b.position.z)
      }
      bones.each { |b|
        if b.parent
          multiplied_matrices[b.index] = multiplied_matrices[b.parent.index] * matrices[b.index]
        else
          multiplied_matrices[b.index] = matrices[b.index]
        end
      }
      bones.each { |b|
        v = multiplied_matrices[b.index] * Linalg::Vector::new( 0.0, 0.0, 0.0 )
        b.position.x = v.x
        b.position.y = v.y
        b.position.z = v.z
        b.relative_position = nil
      }
      set_bone_structure(bones)
      multiplied_matrices = bones.collect { |b|
        multiplied_matrices[b.index] * inverse_bind_pose[b.index]
      }
      vertex_usage = get_vertex_usage
      vertex_usage.each { |vi, bs|
        bone_refs = bs.first.bone_refs
        bone_infos = get_vertex_field(:bone_infos, vi)
        indexes_and_weights = bone_infos.get_indexes_and_weights
        vertex_matrix = Linalg::get_zero_matrix
        indexes_and_weights.each { |bi, bw|
          i = bone_refs[bi]
          vertex_matrix = vertex_matrix + multiplied_matrices[i] * (bw.to_f/255.to_f)
        }
        normal_matrix = vertex_matrix.inverse.transpose
        vp = get_vertex_field(:position, vi)
        new_vp = vertex_matrix * Linalg::Vector::new(vp.x, vp.y, vp.z)
        vp.x = new_vp.x
        vp.y = new_vp.y
        vp.z = new_vp.z
        n = get_vertex_field(:normal, vi)
        new_n = (normal_matrix * Linalg::Vector::new(n.x, n.y, n.z, 0.0)).normalize
        n.x = new_n.x
        n.y = new_n.y
        n.z = new_n.z
        t = get_vertex_field(:tangents, vi)
        new_t = (normal_matrix * Linalg::Vector::new(t.x, t.y, t.z, 0.0)).normalize
        t.x = new_t.x
        t.y = new_t.y
        t.z = new_t.z
        p2 = get_vertex_field(:position2, vi)
        if p2
          new_p2 = vertex_matrix * Linalg::Vector::new(p2.x, p2.y, p2.z)
          p2.x = new_p2.x
          p2.y = new_p2.y
          p2.z = new_p2.z
        end
      }
      self
    end

    def restrict_bones(used_bones)
      bones = get_bone_structure
      used_bones_array = used_bones.to_a.sort
      bone_map = used_bones_array.each_with_index.collect.to_h
      new_bones = used_bones_array.collect { |bi|
        b = bones[bi].dup
        b.index = bone_map[b.index]
        b
      }
      new_bones.each { |b|
        b.parent = new_bones[bone_map[b.parent.index]] if b.parent
      }
      set_bone_structure(new_bones)

      table = @bone_index_translate_table.table
      new_table = table.select { |k,v|
        used_bones.include? v
      }
      new_table = new_table.collect { |k, v| [k, bone_map[v]] }.to_h
      @bone_index_translate_table.table = new_table
      @meshes.each_with_index { |m, i|
        m.batches.each_with_index { |b, j|
          b.bone_refs.collect! { |bi|
            new_bi = bone_map[bi]
            raise "Bone #{bi} was deleted bu is still used by mesh #{i} batch #{j}!" unless new_bi
            new_bi
          }
        }
      }
      self
    end
    private :restrict_bones

    def remap_bones(bone_map)
      raise "Global index specified multiple times!" unless bone_map.values.uniq.size == bone_map.size
      local_to_global = @bone_index_translate_table.table.invert
      unknown_bones = bone_map.keys - local_to_global.keys
      raise "Unknown bones: #{unknown_bones}!" unless unknown_bones.size == 0
      global_tt = {}
      bone_map.each { |k, v|
        global_tt[local_to_global.delete(k)] = v
      }
      puts global_tt
      table = local_to_global.invert
      new_global_indexes = bone_map.values - table.keys
      raise "Global indexes: #{bone_map.values - new_global_indexes} still in use!" unless new_global_indexes.size == bone_map.size
      bone_map.each { |k, v|
        table[v] = k
      }
      @bone_symmetries.collect! { |k|
        global_tt[k] ? global_tt[k] : k
      } if @bone_symmetries
      @bone_index_translate_table.table = table
      self
    end

    def delete_meshes(list)
      kept_meshes = @meshes.size.times.to_a - list
      @meshes = kept_meshes.collect { |i|
        @meshes[i]
      }
      @header.num_meshes = @meshes.size
      self
    end

    def split_meshes(list)
      kept_meshes = @meshes.size.times.to_a - list
      split_meshes = @meshes.size.times.to_a - kept_meshes
      new_meshes = []
      split_meshes.each { |i|
        @meshes[i].batches.each_with_index { |b, j|
          new_mesh = @meshes[i].dup
          new_mesh.header = @meshes[i].header.dup
          new_mesh.header.name = @meshes[i].header.name.tr("\x00","") + ("_%02d" % j)
          new_mesh.batches = [b]
          new_meshes.push new_mesh
        }
      }
      @meshes = kept_meshes.collect { |i|
        @meshes[i]
      }
      @meshes += new_meshes
      @header.num_meshes = @meshes.size
      self
    end

    def duplicate_meshes(list)
      @meshes += list.collect { |i|
        @meshes[i].duplicate(@positions, @vertexes, @vertexes_ex_data)
      }
      @header.num_meshes = @meshes.size
      @header.num_vertexes = @vertexes.size
      self
    end

    def swap_meshes(hash)
      hash.each { |k, v|
        raise "Mesh #{k} was not found in the model!" unless @meshes[k]
        raise "Mesh #{v} was not found in the model!" unless @meshes[v]
        tmp = @meshes[k]
        @meshes[k] =  @meshes[v]
        @meshes[v] = tmp
      }
      self
    end

    def move_meshes(positions)
      raise "Invalid positions!" unless positions.size > 0
      positions.each { |k, v|
        raise "Mesh #{k} was not found in the model!" unless @meshes[k]
        raise "Invalid target position #{v}!" unless v >= 0 && v < @meshes.length
      }
      raise "Duplicate mesh found!" unless positions.keys.uniq.size == positions.size
      raise "Duplicate target position found!" unless positions.values.uniq.size == positions.size
      m_p = positions.to_a.sort { |(m1, _), (m2, _)| m2 <=> m1 }
      m_a = m_p.collect { |m, p|
        [@meshes.delete_at(m), p]
      }.sort { |(_, p1), (_, p2)| p1 <=> p2 }
      m_a.each { |m, p|
        @meshes.insert(p, m)
      }
      self
    end

    def merge_meshes(hash)
      hash.each { |k, vs|
        raise "Mesh #{k} was not found in the model!" unless @meshes[k]
        vs = [vs].flatten
        vs.each { |v|
          raise "Mesh #{v} was not found in the model!" unless @meshes[v]
          @meshes[k].batches += @meshes[v].batches
        }
        @meshes[k].header.num_batch = @meshes[k].batches.length
      }
      self
    end

    def delete_bones(list)
      used_bones = (@header.num_bones.times.to_a - list)
      restrict_bones(used_bones)
      self
    end

    def cleanup_textures(input_name, overwrite)
      if File.exist?(input_name.gsub(".wmb",".wtb"))
        wtb = WTBFile::new(File::new(input_name.gsub(".wmb",".wtb"), "rb"))
        if overwrite
          output_name = input_name.gsub(".wmb",".wtb")
        else
          output_name = "wtb_output/#{File.basename(input_name, ".wmb")}.wtb"
        end
        wtp = false
      elsif File.exist?(input_name.gsub(".wmb",".wta"))
        wtb = WTBFile::new(File::new(input_name.gsub(".wmb",".wta"), "rb"), true, File::new(input_name.gsub(".wmb",".wtp"), "rb"))
        if overwrite
          output_name = input_name.gsub(".wmb",".wta")
        else
          output_name = "wtb_output/#{File.basename(input_name, ".wmb")}.wta"
        end
        wtp = true
      else
        raise "Could not find texture file!"
      end

      available_textures = {}
      digests = []
      wtb.each.with_index { |(info, t), i|
        if @tex_info #Bayo 2
          digest = Digest::SHA1.hexdigest(t.read)
          available_textures[info[2]] = digest
          digests.push( digest )
        else #Bayo 1
          digest = Digest::SHA1.hexdigest(t.read)
          available_textures[i] = digest
          digests.push( digest )
        end
        t.rewind
      }
      used_textures_digest_map = {}
      used_texture_digests = Set[]
      @materials.each { |m|
        m.material_data[0..4].each { |tex_id|
          if available_textures.key?(tex_id)
            digest = available_textures[tex_id]
            used_textures_digest_map[tex_id] = digest
            used_texture_digests.add(digest)
          end
        }
      }
      index_list = digests.each_with_index.collect { |d,i| [i,d] }.select { |i, d|
        used_texture_digests.delete?(d)
      }.collect { |i,d| i }
      new_wtb = WTBFile::new(nil, wtb.big, wtp)
      j = 0
      digest_to_tex_id_map = {}
      wtb.each.with_index { |(info, t), i|
        if index_list.include?(i)
          new_wtb.push( t, info[1], info[2])
          if @tex_info
            digest_to_tex_id_map[digests[i]] = info[2]
          else
            digest_to_tex_id_map[digests[i]] = j
          end
          j += 1
        end
      }
      new_wtb.dump(output_name)
      @materials.each { |m|
        m.material_data[0..4].each_with_index { |tex_id, i|
          if available_textures.key?(tex_id)
            digest = available_textures[tex_id]
            m.material_data[i] = digest_to_tex_id_map[digest]
          end
        }
      }
    end

    def advanced_materials
      if is_bayo2?
        materials
      else
        materials.collect { |m|
          if $material_db[m.type][:layout]
            Bayo1Material::new(m)
          else
            m
          end
        }
      end
    end

    def cleanup_materials
      used_materials = Set[]
      @meshes.each { |m|
        m.batches.each { |b|
          if @tex_infos #Bayo 2
            used_materials.add(b.header.ex_mat_id)
          else #Bayo 1
            used_materials.add(b.header.material_id)
          end
        }
      }
      materials = @header.num_materials.times.to_a
      kept_materials = materials & used_materials.to_a
      correspondance_table = kept_materials.each_with_index.to_h
      @materials.select!.with_index { |_, i| used_materials.include?(i) }
      @header.num_materials = used_materials.size
      if @shader_names
        @shader_names.select!.with_index { |_, i| used_materials.include?(i) }
      end
      @meshes.each { |m|
        m.batches.each { |b|
          if @tex_infos
            b.header.ex_mat_id = correspondance_table[b.header.ex_mat_id]
          else
            b.header.material_id = correspondance_table[b.header.material_id]
          end
        }
      }
      self
    end

    def cleanup_material_sizes
      raise "Unsupported for Bayonetta 2!" if @shader_names
      @materials.each { |m|
         type = m.type
         if $material_db.key?(type) && $material_db[type][:size]
           size = $material_db[type][:size]
         else
           warn "Unknown material type #{m.type}!"
           next
         end
         data_number = (size - 4)/4
         m.material_data = m.material_data.first(data_number)
      }
      self
    end

    def maximize_material_sizes
      raise "Unsupported for Bayonetta 2!" if @shader_names
      max_size_mat = $material_db.select { |k, v| v[:size] }.max_by { |k, v|
        v[:size]
      }
      max_data_number = (max_size_mat[1][:size] - 4)/4
      @materials.each { |m|
        m.material_data = m.material_data + [0]*(max_data_number - m.material_data.size)
      }
      self
    end

    def cleanup_bone_refs
      @meshes.each { |m|
        m.batches.each { |b|
          b.cleanup_bone_refs(@vertexes)
        }
      }
      self
    end

    def add_ancestors_bone_refs
      @meshes.each { |m|
        m.batches.each { |b|
          b.add_ancestors_bone_refs(@vertexes, get_bone_structure)
        }
      }
      self
    end

    def add_previous_bone_refs
      @meshes.each { |m|
        m.batches.each { |b|
          b.add_previous_bone_refs(@vertexes, get_bone_structure)
        }
      }
      self
    end

    def cleanup_bones
      used_bones = Set[]
      @meshes.each { |m|
        m.batches.each { |b|
          used_bones.merge b.bone_refs
        }
      }
      bones = get_bone_structure
      used_bones.to_a.each { |bi|
        used_bones.merge bones[bi].parents.collect(&:index)
      }
      restrict_bones(used_bones)
      self
    end

    def dump_bones(list = nil)
      bone_struct = Struct::new(:index, :parent, :relative_position, :position, :global_index, :symmetric, :flag)
      table = @bone_index_translate_table.table.invert
      list = (0...@header.num_bones) unless list
      list.collect { |bi|
        bone_struct::new(bi, @bone_hierarchy[bi], @bone_relative_positions[bi], @bone_positions[bi], table[bi],  @header.offset_bone_symmetries > 0x0 ? @bone_symmetries[bi] : -1, @header.offset_bone_flags > 0x0 ? @bone_flags[bi] : 5)
      }
    end

    def import_bones( list )
      table = @bone_index_translate_table.table
      @header.num_bones += list.length
      list.each { |b|
        table[b[:global_index]] = b[:index]
        @bone_hierarchy.push b[:parent]
        @bone_relative_positions.push b[:relative_position]
        @bone_positions.push b[:position]
        @bone_symmetries.push b[:symmetric] if @header.offset_bone_symmetries > 0x0
        @bone_flags.push b[:flag] if @header.offset_bone_flags > 0x0
      }
      @bone_index_translate_table.table = table
      self
    end

    def remove_triangle_strips
      @meshes.each { |m|
        m.batches.each { |b|
          b.set_triangles(b.triangles)
        }
      }
    end

    def cleanup_vertexes
      used_vertex_indexes = []
      @meshes.each { |m|
        m.batches.each { |b|
          used_vertex_indexes += b.vertex_indices
        }
      }
      used_vertex_indexes = used_vertex_indexes.sort.uniq
      @vertexes = used_vertex_indexes.collect { |i| @vertexes[i] }
      @vertexes_ex_data = used_vertex_indexes.collect { |i| @vertexes_ex_data[i] } if @vertexes_ex_data
      @header.num_vertexes = @vertexes.size
      vertex_map = used_vertex_indexes.each_with_index.to_h
      @meshes.each { |m|
        m.batches.each { |b|
          b.indices.collect! { |i|
            vertex_map[i + b.header.vertex_offset]
          }
          b.recompute_from_absolute_indices
        }
      }
      self
    end

    def get_vertex_usage
      vertex_usage = Hash::new { |h, k| h[k] = [] }
      @meshes.each { |m|
        m.batches.each { |b|
          b.vertex_indices.each { |i|
            vertex_usage[i].push(b)
          }
        }
      }
      vertex_usage.each { |k,v| v.uniq! }
      vertex_usage
    end

    # Duplicate vertexes used by several batches
    def normalize_vertex_usage
      vertex_usage = get_vertex_usage
      vertex_usage.select! { |k, v| v.length > 1 }
      batches = Set::new
      vertex_usage.each { |vi, blist|
        batches.merge blist[1..-1]
      }
      batches.each { |b|
        new_batch = b.duplicate(@vertexes, @vertexes_ex_data)
        b.header = new_batch.header
        b.indices = new_batch.indices
      }
      @header.num_vertexes = @vertexes.size
      self
    end

    def copy_vertex_properties(vertex_hash, **options)
      vertex_usage = nil
      vertex_usage = get_vertex_usage if options[:bone_infos]
      vertex_hash.each { |ivi, ovis|
        ovis = [ovis].flatten
        ovis.each { |ovi|
          iv = @vertexes[ivi]
          ov = @vertexes[ovi]
          if options[:position]
            if @positions
              @positions[ovi].x = @positions[ivi].x
              @positions[ovi].y = @positions[ivi].y
              @positions[ovi].z = @positions[ivi].z
            end
            if ov.respond_to?(:position)
              ov.position.x = iv.position.x
              ov.position.y = iv.position.y
              ov.position.z = iv.position.z
            end
            if ov.respond_to?(:position2)
              ov.position2.x = iv.position2.x
              ov.position2.y = iv.position2.y
              ov.position2.z = iv.position2.z
            end
            if @vertexes_ex_data
              if @vertexes_ex_data[ovi].respond_to?(:position2)
                @vertexes_ex_data[ovi].position2.x = @vertexes_ex_data[ivi].position2.x
                @vertexes_ex_data[ovi].position2.y = @vertexes_ex_data[ivi].position2.y
                @vertexes_ex_data[ovi].position2.z = @vertexes_ex_data[ivi].position2.z
              end
            end
          end
          if options[:mapping]
            if ov.respond_to?(:mapping) 
              ov.mapping.u = iv.mapping.u
              ov.mapping.v = iv.mapping.v
            end
            if ov.respond_to?(:mapping2)
              ov.mapping2.u = iv.mapping2.u
              ov.mapping2.v = iv.mapping2.v
            end
            if @vertexes_ex_data && @vertexes_ex_data[ovi].respond_to?(:mapping2)
              @vertexes_ex_data[ovi].mapping2.u = @vertexes_ex_data[ivi].mapping2.u
              @vertexes_ex_data[ovi].mapping2.v = @vertexes_ex_data[ivi].mapping2.v
            end
          end
          if options[:normal]
            ov.normal = iv.normal
          end
          if options[:tangents]
            ov.tangents = iv.tangents
          end
          if options[:color]
            if ov.respond_to?(:color)
              ov.color = iv.color
            end
            if @vertexes_ex_data && @vertexes_ex_data[ovi].respond_to?(:color)
              @vertexes_ex_data[ovi].color = @vertexes_ex_data[ivi].color
            end
          end
          if options[:bone_infos] && ov.respond_to?(:bone_infos)
            input_batches = vertex_usage[ivi]
            raise "Unormalized vertex #{ivi} , normalize first, and recompute vertex numbers!" if input_batches.length > 1
            raise "Unused vertex #{ivi}!" if input_batches.length == 0
            output_batches = vertex_usage[ovi]
            raise "Unormalized vertex #{ovi} , normalize first, and recompute vertex numbers!" if output_batches.length > 1
            raise "Unused vertex #{ovi}!" if output_batches.length == 0
            input_batch = input_batches.first
            output_batch = output_batches.first
            input_bone_indexes_and_weights = iv.bone_infos.get_indexes_and_weights
            output_bone_indexes_and_weights = input_bone_indexes_and_weights.collect { |bi, bw|
              [input_batch.bone_refs[bi], bw]
            }.collect { |bi, bw|
              new_bi = output_batch.bone_refs.find_index(bi)
              unless new_bi
                new_bi = output_batch.bone_refs.length
                output_batch.bone_refs.push(bi)
                output_batch.num_bone_ref = output_batch.bone_refs.length
              end
              [new_bi, bw]
            }
            ov.bone_infos.set_indexes_and_weights( output_bone_indexes_and_weights )
          end
        }
      }
      self
    end

    def renumber_batches
      @meshes.each_with_index { |m, i|
        m.header.id = i
        m.batches.each { |b|
          b.header.mesh_id = i
        }
      }
      self
    end

    def remove_batch_vertex_offsets
      @meshes.each { |m|
        m.batches.each { |b|
          b.indices = b.vertex_indices
          b.recompute_from_absolute_indices
        }
      }
      self
    end

    def fix_ex_data
      @vertexes.each_with_index { |v, i|
        if @vertexes_ex_data[i].respond_to?(:color)
          @vertexes_ex_data[i].color.data = 0xffc0c0c0
        end
        if @vertexes_ex_data[i].respond_to?(:mapping2) 
          @vertexes_ex_data[i].mapping2.u = v.mapping.u
          @vertexes_ex_data[i].mapping2.v = v.mapping.v
        end
      }
    end

    def copy_uv12(mesh_list)
      raise "No UV2 in model!" unless @vertexes_ex_data[0].respond_to?(:mapping2)
      mesh_list.each { |i|
        @meshes[i].batches.each { |b|
          b.vertex_indices.each { |vi|
            @vertexes_ex_data[vi].mapping2.u = @vertexes[vi].mapping.u
            @vertexes_ex_data[vi].mapping2.v = @vertexes[vi].mapping.v
          }
        }
      }
    end

    def reverse_tangents_byte_order(mesh_list)
      raise "Vertex don't have tangents information!" unless @vertexes[0].respond_to?(:tangents)
      vertex_indices = []
      mesh_list.each { |i|
        @meshes[i].batches.each { |b|
          vertex_indices += b.vertex_indices
        }
      }
      vertex_indices.uniq!
      vertex_indices.each { |i|
        @vertexes[i].tangents.data = [@vertexes[i].tangents.data].pack("L<").unpack("L>").first
      }
    end

    def recompute_layout
      get_vertex_types

      if is_bayo2?
        last_offset = 0xc0
      else
        last_offset = 0x80
      end

      @header.num_vertexes = @vertexes.size if @vertexes

      if @header.offset_positions > 0x0
        last_offset = @header.offset_positions = align(last_offset, 0x20)
        last_offset += @header.num_vertexes * 12
      end

      if @header.offset_vertexes > 0x0
        last_offset = @header.offset_vertexes = align(last_offset, 0x20)
        last_offset += @header.num_vertexes * @vertex_size
      end
      if @header.offset_vertexes_ex_data > 0x0
        last_offset += 0x20 if is_bayo2?
        last_offset = @header.offset_vertexes_ex_data = align(last_offset, 0x20)
        last_offset += @header.num_vertexes * @vertex_ex_size
      end
      if @header.offset_bone_relative_position > 0x0
        last_offset = @header.offset_bone_hierarchy = align(last_offset, 0x20)
        last_offset += @header.num_bones * 2
      end
      if @header.offset_bone_relative_position > 0x0
        last_offset = @header.offset_bone_relative_position = align(last_offset, 0x20)
        last_offset += @header.num_bones * 12
      end
      if @header.offset_bone_position > 0x0
        last_offset = @header.offset_bone_position = align(last_offset, 0x20)
        last_offset += @header.num_bones * 12
      end
      if @header.offset_bone_index_translate_table > 0x0
        last_offset = @header.offset_bone_index_translate_table = align(last_offset, 0x20)
        last_offset += @bone_index_translate_table.size
      end
      if @header.offset_u_j > 0x0
        last_offset = @header.offset_u_j = align(last_offset, 0x20)
        last_offset += @u_j.size
      end
      if @header.offset_bone_symmetries > 0x0
        last_offset = @header.offset_bone_symmetries = align(last_offset, 0x20)
        last_offset += @header.num_bones * 2
      end
      if @header.offset_bone_flags > 0x0
        last_offset = @header.offset_bone_flags = align(last_offset, 0x20)
        last_offset += @header.num_bones
      end
      if @header.offset_shader_names > 0x0
        last_offset = @header.offset_shader_names = align(last_offset, 0x20)
        last_offset += @header.num_materials * 16
      end
      if @header.offset_tex_infos > 0x0
        last_offset = @header.offset_tex_infos = align(last_offset, 0x20)
        last_offset += 4 + @tex_infos.num_tex_infos * 8
      end

      last_offset = @header.offset_materials_offsets = align(last_offset, 0x20)
      off = 0
      @materials_offsets = []
      @header.num_materials.times { |i|
        @materials_offsets.push off
        off += @materials[i].size
        off =  align(off, 0x4)
      }

      last_offset += 4*@header.num_materials
      last_offset = @header.offset_materials = align(last_offset, 0x20)

      last_offset +=  @materials.collect(&:size).reduce(&:+)
      last_offset = @header.offset_meshes_offsets = align(last_offset, 0x20)

      off = 0
      @meshes_offsets = []
      @header.num_meshes.times { |i|
        @meshes[i].recompute_layout
        @meshes_offsets.push off
        off += @meshes[i].size
        off = align(off, 0x20)
      }

      last_offset += 4*@header.num_meshes
      last_offset = @header.offset_meshes = align(last_offset, 0x20)
    end

  end

end
