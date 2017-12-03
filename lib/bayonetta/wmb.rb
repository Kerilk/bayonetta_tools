require 'set'
module Bayonetta

  class WMBFile < DataConverter
    include Alignment

    class VertexExData1 < DataConverter
      register_field :unknown, :L
    end

    class VertexExData2 < DataConverter
      register_field :unknown, :L
      register_field :u, :S
      register_field :v, :S
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

      def self.dump(output, output_big, parent, index)
        vertex_ex_data_size = parent.header.vertex_ex_data_size
        if vertex_ex_data_size == 1
          return VertexExData1::convert(output, output_big, parent, index)
        else
          return VertexExData2::convert(output, output_big, parent, index)
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

    class Vertex < DataConverter
      register_field :x, :L
      register_field :y, :L
      register_field :z, :L
      register_field :u, :S
      register_field :v, :S
      register_field :normals, Normals
      register_field :unknown, :L
      register_field :bone_index, :L
      register_field :bone_weight, :L

    end

    class BonePosition < DataConverter
      register_field :x, :L
      register_field :y, :L
      register_field :z, :L

      def xf
        [@x].pack("L").unpack("f").first
      end

      def yf
        [@y].pack("L").unpack("f").first
      end

      def zf
        [@z].pack("L").unpack("f").first
      end

      def xf=(val)
        @x = [val].pack("f").unpack("L").first
      end

      def yf=(val)
        @y = [val].pack("f").unpack("L").first
      end

      def zf=(val)
        @z = [val].pack("f").unpack("L").first
      end

      def -(other)
        b = BonePosition::new
        b.xf = xf - other.xf
        b.yf = yf - other.yf
        b.zf = zf - other.zf
        b
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
      register_field :num_bone_ref, :l
    end

    class Batch < DataConverter
      register_field :header, BatchHeader
      register_field :bone_refs, :C, count: 'header\num_bone_ref'
      register_field :indices, :S, count: 'header\num_indices', offset: '__position + header\offset_indices'

      def size(position = 0, parent = nil, index = nil)
        sz = @header.offset_indices
        sz += @header.num_indices * 2
        sz
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
        off = @header.num_batch * 4
        @header.num_batch.times { |j|
          off = align(off, 0x20)
          @batch_offsets[j] = off
          off += @batches[j].size
        }
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
      register_field :offset_bone_infos, :L
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
    register_field :bone_relative_positions, BonePosition, count: 'header\num_bones',
                   offset: 'header\offset_bone_relative_position'
    register_field :bone_positions, BonePosition, count: 'header\num_bones', offset: 'header\offset_bone_position'
    register_field :bone_index_translate_table, BoneIndexTranslateTable,
                   offset: 'header\offset_bone_index_translate_table'
    register_field :u_j, UnknownStruct, offset: 'header\offset_u_j'
    register_field :bone_infos, :s, count: 'header\num_bones', offset: 'header\offset_bone_infos'
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
      @__was_big = input_big

      if output_name.respond_to?(:write) && output_name.respond_to?(:seek)
        output = output_name
      else
        output = File.open(output_name, "wb")
      end
      output.write("\xFB"*input.size)
      output.rewind

      wmb = self::new
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
      @__was_big = input_big

      wmb = self::new
      wmb.load(input, input_big)
      input.close unless input_name.respond_to?(:read) && input_name.respond_to?(:seek)

      wmb
    end

    def was_big?
      @__was_big
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
        b.info = @bone_infos[i] if @header.offset_bone_infos > 0x0
        b.flag = @bone_flags[i] if @header.offset_bone_flags > 0x0
      }
    end

    def set_bone_structure(bones)
      @bone_hierarchy = []
      @bone_relative_positions = []
      @bone_positions = []
      @bone_infos = [] if @header.offset_bone_infos > 0x0
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
        @bone_infos.push b.info if @header.offset_bone_infos > 0x0
        @bone_flags.push b.flag if @header.offset_bone_flags > 0x0
      }
      @header.num_bones = bones.size
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
      @meshes.each { |m|
        m.batches.each { |b|
          b.bone_refs.collect! { |bi| bone_map[bi] }
        }
      }
      self
    end

    def cleanup_vertexes
      used_vertex_indexes = []
      @meshes.each { |m|
        m.batches.each { |b|
          used_vertex_indexes += (b.header.vertex_start...b.header.vertex_end).to_a
        }
      }
      used_vertex_indexes = used_vertex_indexes.sort.uniq
      @vertexes = used_vertex_indexes.collect { |i| @vertexes[i] }
      @vertexes_ex_data = used_vertex_indexes.collect { |i| @vertexes_ex_data[i] }
      @header.num_vertexes = @vertexes.size
      vertex_map = used_vertex_indexes.each_with_index.to_h
      @meshes.each { |m|
        m.batches.each { |b|
          offset = vertex_map[b.header.vertex_start] - b.header.vertex_start
          b.header.vertex_start += offset
          b.header.vertex_end += offset
          b.header.vertex_offset += offset
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
    end

    def remove_batch_vertex_offsets
      @meshes.each { |m|
        m.batches.each { |b|
          offset = b.header.vertex_offset
          b.indices.collect! { |index|
            index + offset
          }
          b.header.vertex_offset = 0
        }
      }
    end

    def recompute_layout
      last_offset = @header.offset_vertexes

      last_offset += @header.num_vertexes * 32
      last_offset = @header.offset_vertexes_ex_data = align(last_offset, 0x20)

      last_offset += @header.num_vertexes * @header.vertex_ex_data_size * 4
      last_offset = @header.offset_bone_hierarchy = align(last_offset, 0x20)

      last_offset += @header.num_bones * 2
      last_offset = @header.offset_bone_relative_position = align(last_offset, 0x20)

      last_offset += @header.num_bones * 12
      last_offset = @header.offset_bone_position = align(last_offset, 0x20)

      last_offset += @header.num_bones * 12
      last_offset = @header.offset_bone_index_translate_table = align(last_offset, 0x20)

      last_offset += @bone_index_translate_table.size
      if @header.offset_u_j > 0x0
        last_offset = @header.offset_u_j = align(last_offset, 0x20)
        last_offset += @u_j.size
      end
      if @header.offset_bone_infos > 0x0
        last_offset = @header.offset_bone_infos = align(last_offset, 0x20)
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
