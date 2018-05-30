require 'set'
require 'digest'
module Bayonetta
  class WMBFile < DataConverter
    include Alignment

    class UByteList < DataConverter
      register_field :data, :L

      def self.inherited(subclass)
        subclass.instance_variable_set(:@fields, @fields.dup)
      end

      def self.convert(input, output, input_big, output_big, parent, index)
        h = self::new
        if parent.__parent.is_bayo2? && input_big
          h.convert(input, output, false, output_big, parent, index)
        else
          h.convert(input, output, input_big, output_big, parent, index)
        end
        h
      end

      def self.load(input, input_big, parent, index)
        h = self::new
        if parent.__parent.is_bayo2? && input_big
          h.load(input, false, parent, index)
        else
          h.load(input, input_big, parent, index)
        end
        h
      end

      def dump(output, output_big, parent = nil, index = nil)
        if parent.__parent.is_bayo2? && output_big
          set_dump_type(output, false, parent, index)
        else
          set_dump_type(output, output_big, parent, index)
        end
        dump_fields
        unset_dump_type
        self
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

    class Tangents < UByteList
    end

    class VertexExData1 < DataConverter
      register_field :color, Color
    end

    class Mapping < DataConverter
      register_field :u, :S
      register_field :v, :S
    end

    class VertexExData2 < DataConverter
      register_field :color, Color
      register_field :mapping, Mapping
    end

    class VertexExData < DataConverter

      def self.convert(input, output, input_big, output_big, parent, index)
        vertex_ex_data_size = parent.header.vertex_ex_data_size
        if vertex_ex_data_size == 1
          return VertexExData1::convert(input, output, input_big, output_big, parent, index)
        else
          return VertexExData2::convert(input, output, input_big, output_big, parent, index)
        end
      end

      def self.load(input, input_big, parent, index)
        vertex_ex_data_size = parent.header.vertex_ex_data_size
        if vertex_ex_data_size == 1
          return VertexExData1::load(input, input_big, parent, index)
        else
          return VertexExData2::load(input, input_big, parent, index)
        end
      end

    end

    class Normals < DataConverter

      def size(position, parent, index)
        4
      end

      def normalize(fx, fy, fz)
        nrm = Math::sqrt(fx*fx+fy*fy+fz*fz)
        return [0.0, 0.0, 0.0] if nrm == 0.0
        [fx/nrm, fy/nrm, fz/nrm]
      end

      def decode_big_normals(vs)
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

      def decode_small_normals(v)
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

      def encode_small_normals(normals)
        fx = normals[0]
        fy = normals[1]
        fz = normals[2]
        nx = (fx*127.0).to_i
        ny = (fy*127.0).to_i
        nz = (fz*127.0).to_i
        nx = clamp(nx, 127, -128)
        ny = clamp(ny, 127, -128)
        nz = clamp(nz, 127, -128)
        [0, nz, ny, nx].pack("c4")
      end

      def encode_big_normals(normals)
        fx = normals[0]
        fy = normals[1]
        fz = normals[2]
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

      def load_normals
        s = @input.read(4)
        if @input_big
          @normals_big_orig = s
          @normals_small_orig = nil
          @normals = decode_big_normals(s)
        else
          @normals_small_orig = s
          @normals_big_orig = nil
          @normals = decode_small_normals(s)
        end
      end

      def dump_normals
        if @output_big
          s2 = (@normals_big_orig ? @normals_big_orig : encode_big_normals(@normals))
        else
          s2 = (@normals_small_orig ? @normals_small_orig : encode_small_normals(@normals))
        end
        @output.write(s2)
      end

      def convert_normals
        load_normals
        dump_normals
      end

      def convert_fields
        convert_normals
      end

      def load_fields
        load_normals
      end

      def dump_fields
        dump_normals
      end

    end

    class Position < DataConverter
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
      end

      def to_yaml_properties
        [:@x, :@y, :@z]
      end

      def to_s
        "<#{@x}, #{@y}, #{@z}>"
      end

    end

    class Vertex1 < DataConverter
      register_field :position, Position
      register_field :mapping, Mapping
      register_field :normals, Normals
      register_field :tangents, Tangents
      register_field :bone_index, UByteList
      register_field :bone_weight, UByteList

      def get_bone_indexes_and_weights
        res = []
        4.times { |i|
          bi = (@bone_index.data >> (i*8)) & 0xff
          bw = (@bone_weight.data >> (i*8)) & 0xff
          res.push [bi, bw] if bw > 0
        }
        res
      end

      def get_bone_indexes
        get_bone_indexes_and_weights.collect { |bi, _| bi }
      end

      def remap_bone_indexes(map)
        new_bone_info = get_bone_indexes_and_weights.collect { |bi, bw| [map[bi], bw] }
        set_bone_indexes_and_weights(new_bone_info)
        self
      end

      def set_bone_indexes_and_weights(bone_info)
        raise "Too many bone information #{bone_info.inspect}!" if bone_info.length > 4
        @bone_index.data = 0
        @bone_weight.data = 0
        bone_info.each_with_index { |(bi, bw), i|
          raise "Invalid bone index #{bi}!" if bi > 255 || bi < 0
          @bone_index.data |= ( bi << (i*8) )
          bw = 0 if bw < 0
          bw = 255 if bw > 255
          @bone_weight.data |= (bw << (i*8) )
        }
        self
      end

    end

    class Vertex2 < DataConverter
      register_field :position, Position
      register_field :mapping, Mapping
      register_field :normals, Normals
      register_field :unknown_a, :L
      register_field :unknown_b, :L
    end

    class Vertex3 < DataConverter
      register_field :position, Position
      register_field :mapping, Mapping
      register_field :normals, Normals
      register_field :unknown_a, :L
      register_field :unknown_b, :L
      register_field :mapping2, Mapping
    end

    class Vertex4 < DataConverter
      register_field :position, Position
      register_field :mapping, Mapping
      register_field :normals, Normals
      register_field :unknown_a, :L
    end

    class Vertex < DataConverter

      def self.convert(input, output, input_big, output_big, parent, index)
        u_b = parent.header.u_b
        vertex_ex_data_size = parent.header.vertex_ex_data_size
        if (u_b & 0xff) == 0xf
          if vertex_ex_data_size == 1
            return Vertex2::convert(input, output, input_big, output_big, parent, index)
          else
            return Vertex3::convert(input, output, input_big, output_big, parent, index)
          end
        elsif (u_b & 0xff) == 0xd
          if vertex_ex_data_size == 1
            return Vertex4::convert(input, output, input_big, output_big, parent, index)
          else
            raise "Unknown vertex type!"
          end
        else
          return Vertex1::convert(input, output, input_big, output_big, parent, index)
        end
      end

      def self.load(input, input_big, parent, index)
        u_b = parent.header.u_b
        vertex_ex_data_size = parent.header.vertex_ex_data_size
        if (u_b & 0xff) == 0xf
          if vertex_ex_data_size == 1
            return Vertex2::load(input, input_big, parent, index)
          else
            return Vertex3::load(input, input_big, parent, index)
          end
        elsif (u_b & 0xff) == 0xd
          if vertex_ex_data_size == 1
            return Vertex4::load(input, input_big, parent, index)
          else
            raise "Unknown vertex type!"
          end
        else
          return Vertex1::load(input, input_big, parent, index)
        end
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
    end

    class Batch < DataConverter
      register_field :header, BatchHeader
      register_field :num_bone_ref, :l, condition: '(header\u_b & 0x8000) != 0 || (header\u_b & 0x80)'
      register_field :bone_refs, :C, count: 'num_bone_ref', condition: '(header\u_b & 0x8000) != 0 || (header\u_b & 0x80)'
      register_field :unknown, :F, count: 4, condition: '(header\u_b & 0x8000) == 0 && (header\u_b & 0x80) == 0'
      register_field :indices, :S, count: 'header\num_indices', offset: '__position + header\offset_indices'

      def duplicate(vertexes, vertexes_ex)
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
        bone_refs_map = @bone_refs.each_with_index.collect { |b, i| [i, b] }.to_h
        used_bone_refs_indexes = vertex_indices.collect { |vi| vertexes[vi].get_bone_indexes }.flatten.uniq
        new_bone_refs_list = used_bone_refs_indexes.collect{ |i| bone_refs_map[i] }.uniq.sort
        new_bone_refs_reverse_map = new_bone_refs_list.each_with_index.collect { |b, i| [b, i] }.to_h
        translation_map = used_bone_refs_indexes.collect { |ri|
          [ri, new_bone_refs_reverse_map[bone_refs_map[ri]]]
        }.to_h
        vertex_indices.uniq.sort.each { |vi| vertexes[vi].remap_bone_indexes(translation_map) }
        @bone_refs = new_bone_refs_list
        @num_bone_ref = @bone_refs.length
        self
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
      register_field :name, :c, count: 32
      register_field :mat, :L, count: 12
    end

    class Mesh < DataConverter
      register_field :header, MeshHeader
      register_field :batch_offsets, :L, count: 'header\num_batch',
                     offset: '__position + header\offset_batch_offsets'
      register_field :batches, Batch, count: 'header\num_batch', sequence: true,
                     offset: '__position + header\offset_batch_offsets + batch_offsets[__iterator]'

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
        @header.num_batch.times { |j|
          off = align(off, 0x20)
          @batch_offsets[j] = off
          off += @batches[j].size
        }
      end

      def duplicate(vertexes, vertexes_ex)
        m = Mesh::new
        m.header = @header
        m.batch_offsets = @batch_offsets
        m.batches = @batches.collect { |b| b.duplicate(vertexes, vertexes_ex) }
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
      register_field :u_f, :l
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
    register_field :vertexes, Vertex, count: 'header\num_vertexes', offset: 'header\offset_vertexes'
    register_field :vertexes_ex_data, VertexExData, count: 'header\num_vertexes',
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
      @offset_shader_names != 0 || @offset_tex_infos != 0
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
      @vertexes.each { |v|
        v.position.x = v.position.x * s
        v.position.y = v.position.y * s
        v.position.z = v.position.z * s
      }
      @bone_positions.each { |p|
        p.x = p.x * s
        p.y = p.y * s
        p.z = p.z * s
      }
      @bone_relative_positions.each { |p|
        p.x = p.x * s
        p.y = p.y * s
        p.z = p.z * s
      }
      self
    end

    def shift(x, y, z)
      @vertexes.each { |v|
        v.position.x = v.position.x + x
        v.position.y = v.position.y + y
        v.position.z = v.position.z + z
      }
      @bone_positions.each { |p|
        p.x = p.x + x
        p.y = p.y + y
        p.z = p.z + z
      }
      @bone_relative_positions.each { |p|
        p.x = p.x + x
        p.y = p.y + y
        p.z = p.z + z
      }
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
      @vertexes.each { |v|
        r = m * Linalg::Vector::new(v.position.x, v.position.y, v.position.z)
        v.position.x = r.x
        v.position.y = r.y
        v.position.z = r.z
      }
      @bone_positions.each { |p|
        r = m * Linalg::Vector::new(p.x, p.y, p.z)
        p.x = r.x
        p.y = r.y
        p.z = r.z
      }
      recompute_relative_positions
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

    def delete_meshes(list)
      kept_meshes = @meshes.size.times.to_a - list
      @meshes = kept_meshes.collect { |i|
        @meshes[i]
      }
      @header.num_meshes = @meshes.size
      self
    end

    def duplicate_meshes(list)
      @meshes += list.collect { |i|
        @meshes[i].duplicate(@vertexes, @vertexes_ex_data)
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
      material_db = YAML::load_file('material_database.yaml')
      @materials.each { |m|
         type = m.type
         if material_db.key?(type)
           size = material_db[type][:size]
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
      material_db = YAML::load_file('material_database.yaml')
      max_size_mat = material_db.max_by { |k, v|
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
            ov.position.x = iv.position.x
            ov.position.y = iv.position.y
            ov.position.z = iv.position.z
          end
          if options[:mapping]
            ov.mapping.u = iv.mapping.u
            ov.mapping.v = iv.mapping.v
            if ov.respond_to?(:mapping2) && iv.respond_to?(:mapping2)
              ov.mapping2.u = iv.mapping2.u
              ov.mapping2.v = iv.mapping2.v
            end
            if @vertexes_ex_data && @header.vertex_ex_data_size > 1
              @vertexes_ex_data[ovi].mapping.u = @vertexes_ex_data[ivi].mapping.u
              @vertexes_ex_data[ovi].mapping.v = @vertexes_ex_data[ivi].mapping.v
            end
          end
          if options[:normal]
            ov.normals = iv.normals
          end
          if options[:tangents]
            ov.tangents = iv.tangents
          end
          if options[:color] && @vertexes_ex_data
            @vertexes_ex_data[ovi].color = @vertexes_ex_data[ivi].color
          end
          if options[:unknown] && ov.respond_to?(:unknown_a) && iv.respond_to?(:unknown_a)
            ov.unknown_a = iv.unknown_a
          end
          if options[:unknown] && ov.respond_to?(:unknown_b) && iv.respond_to?(:unknown_b)
            ov.unknown_b = iv.unknown_b
          end
          if options[:bone_infos]
            input_batches = vertex_usage[ivi]
            raise "Unormalized vertex #{ivi} , normalize first, and recompute vertex numbers!" if input_batches.length > 1
            raise "Unused vertex #{ivi}!" if input_batches.length == 0
            output_batches = vertex_usage[ovi]
            raise "Unormalized vertex #{ovi} , normalize first, and recompute vertex numbers!" if output_batches.length > 1
            raise "Unused vertex #{ovi}!" if output_batches.length == 0
            input_batch = input_batches.first
            output_batch = output_batches.first
            input_bone_indexes_and_weights = iv.get_bone_indexes_and_weights
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
            ov.set_bone_indexes_and_weights( output_bone_indexes_and_weights )
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
        @vertexes_ex_data[i].color.data = 0xffc0c0c0
        @vertexes_ex_data[i].mapping.u = v.mapping.u
        @vertexes_ex_data[i].mapping.v = v.mapping.v
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
      last_offset = @header.offset_vertexes

      @header.num_vertexes = @vertexes.size
      last_offset += @header.num_vertexes * 32

      if @header.offset_vertexes_ex_data > 0x0
        last_offset = @header.offset_vertexes_ex_data = align(last_offset, 0x20)
        last_offset += @header.num_vertexes * @header.vertex_ex_data_size * 4
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
      @header.num_materials.times { |i|
        @materials_offsets[i] = off
        off += @materials[i].size
        off =  align(off, 0x4)
      }

      last_offset += 4*@header.num_materials
      last_offset = @header.offset_materials = align(last_offset, 0x20)

      last_offset +=  @materials.collect(&:size).reduce(&:+)
      last_offset = @header.offset_meshes_offsets = align(last_offset, 0x20)

      off = 0
      @header.num_meshes.times { |i|
        @meshes[i].recompute_layout
        @meshes_offsets[i] = off
        off += @meshes[i].size
        off = align(off, 0x20)
      }

      last_offset += 4*@header.num_meshes
      last_offset = @header.offset_meshes = align(last_offset, 0x20)
    end

  end

end
