module Bayonetta

  class WMBFile

    class VertexExData1 < DataConverter
      register_field :unknown, :L
    end

    class VertexExData2 < DataConverter
      register_field :unknown, :L
      register_field :u, :S
      register_field :v, :S
    end

    class Vertex < DataConverter
      register_field :x, :L
      register_field :y, :L
      register_field :z, :L
      register_field :u, :S
      register_field :v, :S
      register_field :normals, :L
      register_field :unknown, :L
      register_field :bone_index, :L
      register_field :bone_weight, :L

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

      def convert_normals
        s = @input.read(4)
        if @input_big
          @normals = decode_big_normals(s)
        else
          @normals = decode_small_normals(s)
        end

        if @output_big
          s2 = encode_big_normals(@normals)
        else
          s2 = encode_small_normals(@normals)
        end
        @output.write(s2)
      end

      def convert_fields
        self.class.instance_variable_get(:@fields).each { |field, type, count|
          if field == :normals
            convert_normals
          else
            convert_field(field, type, count)
          end
        }
      end

    end

    class BoneIndex < DataConverter
      register_field :index, :s
    end

    class BoneFlag < DataConverter
      register_field :flag, :c
    end

    class BonePosition < DataConverter
      register_field :x, :L
      register_field :y, :L
      register_field :z, :L
    end

    class BoneIndexTranslateTable < DataConverter
      register_field :offsets, :s, 16

      def convert(input, output, input_big, output_big, level)
        set_convert_type(input, output, input_big, output_big)
        convert_fields
        if level == 1
          @second_levels = []
          @offsets.each { |o|
            if o != -1
              t = self.class::new
              t.convert(input, output, input_big, output_big, level+1)
              @second_levels.push t
            end
          }
          @third_levels = []
          @second_levels.each { |l|
            l.offsets.each { |o|
              if o != -1
                t = self.class::new
                t.convert(input, output, input_big, output_big, level+2)
                @third_levels.push t
              end
            }
          }
        end
      end

      def self.convert(input, output, input_big, output_big)
        h = self::new
        h.convert(input, output, input_big, output_big, 1)
        h
      end

    end

    class UnknownStruct < DataConverter
      register_field :u_a1, :C, 4
      register_field :u_b1, :L
      register_field :u_c1, :s, 4
      register_field :u_a2, :C, 4
      register_field :u_b2, :L
      register_field :u_c2, :s, 4
      register_field :u_a3, :C, 4
      register_field :u_b3, :L
    end

    class MaterialOffset < DataConverter
      register_field :offset, :L
    end

    class MaterialData < DataConverter
      register_field :datum, :L
    end

    class Material < DataConverter
      register_field :type, :s
      register_field :flag, :S

      def convert(input, output, input_big, output_big, elem_num)
        set_convert_type(input, output, input_big, output_big)
        convert_fields
        @material_data = elem_num.times.collect {
          MaterialData::convert(input, output, input_big, output_big)
        }
      end

      def self.convert(input, output, input_big, output_big, elem_num)
        h = self::new
        h.convert(input, output, input_big, output_big, elem_num)
        h
      end
    end

    class BoneRef < DataConverter
      register_field :ref, :C
    end

    class BatchHeader < DataConverter
      register_field :u_a, :s
      register_field :id, :s
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
      register_field :u_f, :l, 7
      register_field :num_bone_ref, :l
    end

    class VertexIndex < DataConverter
      register_field :index, :S
    end

    class Batch < DataConverter
      def convert(input, output, input_big, output_big)
        pos = input.tell
        @header = BatchHeader::convert(input, output, input_big, output_big)
        @bone_refs = @header.num_bone_ref.times.collect {
          BoneRef::convert(input, output, input_big, output_big)
        }
        if @header.offset_indices > 0
          input.seek(pos + @header.offset_indices)
          output.seek(pos + @header.offset_indices)
          @indices = @header.num_indices.times.collect {
            VertexIndex::convert(input, output, input_big, output_big)
          }
        end
      end
    end

    class MeshesOffset < DataConverter
      register_field :offset, :L
    end

    class MeshHeader < DataConverter
      register_field :id, :s
      register_field :num_batch, :s
      register_field :u_a1, :s
      register_field :u_a2, :s
      register_field :offset_batch_offsets, :L
      register_field :u_b, :L
      register_field :u_c, :l, 4
      register_field :name, :c, 32
      register_field :mat, :L, 12
    end

    class BatchOffset < DataConverter
      register_field :offset, :L
    end

    class Mesh < DataConverter
      def convert(input, output, input_big, output_big)
        pos = input.tell
        @header = MeshHeader::convert(input, output, input_big, output_big)
        if @header.offset_batch_offsets > 0
          input.seek(pos + @header.offset_batch_offsets)
          output.seek(pos + @header.offset_batch_offsets)
          @batch_offsets = @header.num_batch.times.collect {
            BatchOffset::convert(input, output, input_big, output_big)
          }
        end

        @batches = @header.num_batch.times.collect { |i|
          input.seek(pos + @header.offset_batch_offsets + @batch_offsets[i].offset)
          output.seek(pos + @header.offset_batch_offsets + @batch_offsets[i].offset)
          Batch::convert(input, output, input_big, output_big)
        }
      end
    end

    class WMBFileHeader < DataConverter
      attr_accessor :id
      register_field :u_a, :l
      register_field :u_b, :l
      register_field :num_vertexes, :l
      register_field :vertex_ex_data_size, :c
      register_field :vertex_ex_data, :c
      register_field :u_e, :s
      register_field :u_f, :l
      register_field :offset_vertexes, :L
      register_field :offset_vertexes_ex_data, :L
      register_field :u_g, :l, 4
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
      register_field :ex_mat_info, :l, 4

      def convert(input, output, input_big, output_big)
        set_convert_type(input, output, input_big, output_big)
        @id = @input.read(4).unpack("a4").first
        @id.reverse! if input_big
        if output_big
          @output.write([@id.reverse].pack("a4"))
        else
          @output.write([@id].pack("a4"))
        end
        convert_fields
      end

    end

    def self.convert(input_name, output_name, output_big = false)
      input = File.open(input_name, "rb")
      id = input.read(4).unpack("a4").first
      case id
      when "WMB\0".b
        input_big = false
      when "\0BMW".b
        input_big = true
      else
        raise "Invalid file type #{id}!"
      end
      output = File.open(output_name, "wb")
      output.write("\xFB"*input.size)
      input.seek(0);
      output.seek(0);
      @header = WMBFileHeader::convert(input, output, input_big, output_big)

      input.seek(@header.offset_vertexes)
      output.seek(@header.offset_vertexes)
      @vertexes = @header.num_vertexes.times.collect {
        Vertex::convert(input, output, input_big, output_big)
      }

      if @header.offset_vertexes_ex_data > 0
        input.seek(@header.offset_vertexes_ex_data)
        output.seek(@header.offset_vertexes_ex_data)
        if @header.vertex_ex_data_size == 1
          @vertexes_ex_data = @header.num_vertexes.times.collect {
            VertexExData1::convert(input, output, input_big, output_big)
          }
        elsif @header.vertex_ex_data_size == 2
          @vertexes_ex_data = @header.num_vertexes.times.collect {
            VertexExData2::convert(input, output, input_big, output_big)
          }
        end
      end

      if @header.offset_bone_hierarchy > 0
        input.seek(@header.offset_bone_hierarchy)
        output.seek(@header.offset_bone_hierarchy)
        @bone_hierarchy = @header.num_bones.times.collect {
          BoneIndex::convert(input, output, input_big, output_big)
        }
      end

      if @header.offset_bone_relative_position > 0
        input.seek(@header.offset_bone_relative_position)
        output.seek(@header.offset_bone_relative_position)
        @bone_relative_positions = @header.num_bones.times.collect {
          BonePosition::convert(input, output, input_big, output_big)
        }
      end

      if @header.offset_bone_position > 0
        input.seek(@header.offset_bone_position)
        output.seek(@header.offset_bone_position)
        @bone_relative_positions = @header.num_bones.times.collect {
          BonePosition::convert(input, output, input_big, output_big)
        }
      end

      if @header.offset_bone_index_translate_table > 0
        input.seek(@header.offset_bone_index_translate_table)
        output.seek(@header.offset_bone_index_translate_table)
        @bone_index_translate_table = BoneIndexTranslateTable::convert(input, output, input_big, output_big)
      end

      if @header.offset_u_j > 0
        input.seek(@header.offset_u_j)
        output.seek(@header.offset_u_j)
        @u_j = UnknownStruct::convert(input, output, input_big, output_big)
      end

      if @header.offset_bone_infos > 0
        input.seek(@header.offset_bone_infos)
        output.seek(@header.offset_bone_infos)
        @bone_infos = @header.num_bones.times.collect {
          BoneIndex::convert(input, output, input_big, output_big)
        }
      end

      if @header.offset_bone_flags > 0
        input.seek(@header.offset_bone_flags)
        output.seek(@header.offset_bone_flags)
        @bone_flags = @header.num_bones.times.collect {
          BoneFlag::convert(input, output, input_big, output_big)
        }
      end

      if @header.offset_materials_offsets > 0
        input.seek(@header.offset_materials_offsets)
        output.seek(@header.offset_materials_offsets)
        @materials_offsets = @header.num_materials.times.collect {
          MaterialOffset::convert(input, output, input_big, output_big)
        }
      end

      if @header.offset_materials > 0
        @materials = (@header.num_materials-1).times.collect { |i|
          input.seek(@header.offset_materials+@materials_offsets[i].offset)
          output.seek(@header.offset_materials+@materials_offsets[i].offset)
          size = @materials_offsets[i+1].offset - @materials_offsets[i].offset - 4
          size = size / 4
          Material::convert(input, output, input_big, output_big, size)
        }
        input.seek(@header.offset_materials+@materials_offsets[-1].offset)
        output.seek(@header.offset_materials+@materials_offsets[-1].offset)
        size =  @header.offset_meshes_offsets -  ( @header.offset_materials + @materials_offsets[-1].offset ) - 4
        size = size / 4
        @materials.push Material::convert(input, output, input_big, output_big, size)
      end

      if @header.offset_meshes_offsets > 0
        input.seek(@header.offset_meshes_offsets)
        output.seek(@header.offset_meshes_offsets)
        @meshes_offsets = @header.num_meshes.times.collect {
          MeshesOffset::convert(input, output, input_big, output_big)
        }
      end

      if @header.offset_meshes > 0
        @meshes = @header.num_meshes.times.collect { |i|
          input.seek(@header.offset_meshes + @meshes_offsets[i].offset)
          output.seek(@header.offset_meshes + @meshes_offsets[i].offset)
          Mesh::convert(input, output, input_big, output_big)
        }
      end

      input.close
      output.close
    end

  end

end
