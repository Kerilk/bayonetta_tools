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
    end

    class BoneIndexTranslateTable < DataConverter
      register_field :offsets, :s, count: 16
      attr_accessor :second_levels
      attr_accessor :third_levels
      def table
        return (@offsets+@second_levels.collect(&:offsets)+@third_levels.collect(&:offsets)).flatten
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
        else
          @second_levels = nil
          @third_levels = nil
        end
        unset_load_type
      end

      def dump(output, output_big, parent, index, level = 1)
        set_dump_type(output, output_big, parent, index)
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
      register_field :u_b, :s
      register_field :ex_mat_id, :s
      register_field :material_id, :C
      register_field :u_d, :c
      register_field :u_e1, :c
      register_field :u_e2, :c
      register_field :vertex_start, :L
      register_field :vertex_end, :L
      register_field :primitive_type, :l
      register_field :offset_indices, :L
      register_field :num_indices, :l
      register_field :vertex_offset, :L
      register_field :u_f, :l, count: 7
      register_field :num_bone_ref, :l
    end

    class Batch < DataConverter
      register_field :header, BatchHeader
      register_field :bone_refs, :C, count: 'header\num_bone_ref'
      register_field :indices, :S, count: 'header\num_indices', offset: '__position + header\offset_indices'
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

      wmb = self::new
      wmb.load(input, input_big)
      input.close unless input_name.respond_to?(:read) && input_name.respond_to?(:seek)

      wmb
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

  end

end
