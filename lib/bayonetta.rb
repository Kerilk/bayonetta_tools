require_relative 'bayonetta/dat.rb'
require_relative 'bayonetta/eff.rb'

module Bayonetta

  def align(val, alignment)
    remainder = val % alignment
    val += alignment - remainder if remainder > 0
    val
  end

  class BayoTex
    attr_reader :name
    attr_reader :base_name
    attr_reader :ext_name
    attr_reader :ext
    attr_reader :size
    attr_reader :f
    def initialize(name)
      @name = name
      @f = File.open(name, "rb")
      @ext_name = File.extname(@name)
      @base_name = File.basename(@name, @ext_name)
      @ext = @ext_name[1..-1]
      @size = @f.size
    end
  end

  class DataConverter
    DATA_SIZES = {
      :c => 1,
      :C => 1,
      :s => 2,
      :S => 2,
      :l => 4,
      :L => 4
    }
    def set_convert_type(input, output, input_big, output_big)
      @input_big = input_big
      @output_big = output_big
      @input = input
      @output = output
    end

    def self.inherited(subclass)
      subclass.instance_variable_set(:@fields, [])
    end

    def self.register_field(field, type, count = 1)
      @fields.push([field, type, count])
      attr_accessor field
    end

    def convert_field(field, type, count)
      it = "#{type}"
      it << "#{@input_big ? ">" : "<"}" if DATA_SIZES[type] > 1
      #ot = "#{type}#{@output_big ? ">" : "<"}"
      vs = count.times.collect {
        s = @input.read(DATA_SIZES[type])
        v = s.unpack(it).first
        s.reverse! if @input_big != @output_big
        @output.write(s)
        v
      }
      vs = vs.first if count == 1
      send("#{field}=", vs)
    end

    def convert_fields
      self.class.instance_variable_get(:@fields).each { |field, type, count|
        convert_field(field, type, count)
      }
    end

    def convert(input, output, input_big, output_big)
      set_convert_type(input, output, input_big, output_big)
      convert_fields
    end

    def self.convert(input, output, input_big, output_big)
      h = self::new
      h.convert(input, output, input_big, output_big)
      h
    end

  end

  class EXPFile

    class EXPFileHeader < DataConverter
      register_field :id, :c, 4
      register_field :u_a, :l
      register_field :u_b, :l
      register_field :num_records, :l
    end

    class Record < DataConverter
      register_field :u_a, :l
      register_field :u_b, :s
      register_field :u_c, :s
      register_field :u_d, :c
      register_field :entry_type, :c
      register_field :u_e, :c
      register_field :u_f, :c
      register_field :u_g, :l
      register_field :offset, :L
    end

    class Entry1 < DataConverter
      register_field :flags, :L
      register_field :u_a, :s
      register_field :u_b, :c
      register_field :u_c, :c
    end

    class Entry2 < DataConverter
      register_field :flags, :L
      register_field :u_a, :s
      register_field :u_b, :c
      register_field :u_c, :c
      register_field :flags2, :L
      register_field :val2, :L
    end

    class Entry3 < DataConverter
      register_field :flags, :L
      register_field :u_a, :s
      register_field :u_b, :c
      register_field :u_c, :c
      register_field :flags2, :L
      register_field :val2, :L
      register_field :flags3, :L
      register_field :val3, :L
    end

    def self.convert(input_name, output_name, input_big = true, output_big = false)
      input = File.open(input_name, "rb")
      id = input.read(4).unpack("a4").first
      raise "Invalid file type #{id}!" unless id == "exp\0".b
      output = File.open(output_name, "wb")
      output.write("\x00"*input.size)
      input.seek(0);
      output.seek(0);

      @header = EXPFileHeader::convert(input, output, input_big, output_big)

      if @header.num_records > 0
        @records = @header.num_records.times.collect {
          Record::convert(input, output, input_big, output_big)
        }
        @entries = @header.num_records.times.collect { |i|
          entry = nil
          if @records[i].offset > 0
            input.seek(@records[i].offset)
            output.seek(@records[i].offset)
            case @records[i].entry_type
            when 1
              entry = Entry1::convert(input, output, input_big, output_big)
            when 2
              entry = Entry2::convert(input, output, input_big, output_big)
            when 3
              entry = Entry3::convert(input, output, input_big, output_big)
            end
          end
          entry
        }
      end
      input.close
      output.close
    end

  end

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

  class WTBFileLayout
    attr_reader :layout
    attr_accessor :unknown
    attr_accessor :texture_flags
    attr_accessor :texture_idx
    ALIGNMENTS = {
      '.dds' => 0x1000,
      '.gtx' => 0x2000
    }
    ALIGNMENTS.default = 0x10

    def initialize
      @layout = {
        :id => 0x0,
        :unknown => 0x4,
        :num_tex => 0x8,
        :offset_texture_offsets => 0xc,
        :offset_texture_sizes => 0x10,
        :offset_texture_flags => 0x14,
        :offset_texture_idx => 0x18,
        :offset_texture_info => 0x1c
      }
      @id = "WTB\0".b
      @unknown = 0x0
      @num_tex = 0
      @offset_texture_offsets = 0x0
      @offset_texture_sizes = 0x0
      @offset_texture_flags = 0x0
      @offset_texture_idx = 0x0
      @offset_texture_infos = 0x0

      @texture_offsets = []
      @texture_sizes = []
      @texture_flags = []
      @texture_idx = []
      @texture_infos = []

      @texture_datas = []
    end

    def files=(files)
      @num_tex = files.length
      @offset_texture_offsets = 0x20
      @offset_texture_sizes = align(@offset_texture_offsets + 4*@num_tex, 0x10)
      @offset_texture_flags = align(@offset_texture_sizes + 4*@num_tex, 0x10)

      @texture_sizes = files.collect { |f| f.size }
      @texture_flags = [0x0]*@num_tex
      file_offset = @offset_texture_flags + 4*@num_tex
      @texture_offsets = files.collect { |f|
        tmp = align(file_offset, ALIGNMENTS[f.ext_name])
        file_offset = align(tmp + f.size, ALIGNMENTS[f.ext_name])
        tmp
      }
      @total_size = align(file_offset, 0x1000)

      @texture_datas = files.collect { |f| f.f.read }
      @texture_types = files.collect { |f| f.ext_name }
    end

    def self.from_files(files)
      l = WTBFileLayout::new
      l.files = files
      return l
    end

    def self.load(file_name)
      l = nil
      File.open(file_name, "rb") { |f|
        l = WTBFileLayout::new
        l.from_file(f)
      }
      l
    end

    def from_file(f)
      id = f.read(4).unpack("a4").first
      case id
      when "WTB\0".b
        texture_type = ".dds"
        t = "L"
        big = false
      when "\0BTW".b
        texture_type = ".gtx"
        t = "N"
        big = true
      else
        raise "Invalid file type #{id}!"
      end
      @total_size = f.size
      @unknown = f.read(4).unpack(t).first
      @num_tex  = f.read(4).unpack(t).first
      @offset_texture_offsets = f.read(4).unpack(t).first
      @offset_texture_sizes = f.read(4).unpack(t).first
      @offset_texture_flags = f.read(4).unpack(t).first
      @offset_texture_idx = f.read(4).unpack(t).first
      @offset_texture_infos = f.read(4).unpack(t).first

      if @offset_texture_offsets != 0
        f.seek(@offset_texture_offsets)
        @texture_offsets = @num_tex.times.collect {
          f.read(4).unpack(t).first
        }
      end

      if @offset_texture_sizes != 0
        f.seek(@offset_texture_sizes)
        @texture_sizes = @num_tex.times.collect {
          f.read(4).unpack(t).first
        }
      end

      if @offset_texture_flags != 0
        f.seek(@offset_texture_flags)
        @texture_flags = @num_tex.times.collect {
          f.read(4).unpack(t).first
        }
        if big then
          @texture_flags.map! { |e|
            b = e & 0x2
            e ^= b
            e
          }
        end
      end

      if @offset_texture_idx != 0
        f.seek(@offset_texture_idx)
        @texture_idx = @num_tex.times.collect {
          f.read(4).unpack(t).first
        }
      end

      if @offset_texture_offsets != 0 && @offset_texture_sizes != 0
        @texture_datas = @texture_offsets.each_with_index.collect { |off, i|
          f.seek(off)
          f.read( @texture_sizes[i] )
        }
      end

      @texture_types = [texture_type]*@num_tex

    end

    def dump_textures(prefix)
      @num_tex.times.collect { |i|
        ext = @texture_types[i]
        name = prefix + "_%03d"%i + ext
        File.open(name, "wb") { |f|
          f.write( @texture_datas[i])
        }
        name
      }
    end

    def dump(name, big = false)
      if big
        t = "N"
      else
        t = "L"
      end
      File.open(name,"wb") { |f|
        f.write("\0"*@total_size)
        f.seek(0)
        if big
          f.write([@id.reverse].pack("a4"))
        else
          f.write([@id].pack("a4"))
        end
        f.write([@unknown].pack(t))
        f.write([@num_tex].pack(t))
        f.write([@offset_texture_offsets].pack(t))
        f.write([@offset_texture_sizes].pack(t))
        f.write([@offset_texture_flags].pack(t))
        f.write([@offset_texture_idx].pack(t))
        f.write([@offset_texture_infos].pack(t))


        if @offset_texture_offsets != 0
          f.seek(@offset_texture_offsets)
          f.write(@texture_offsets.pack(t+"*"))
        end

        if @offset_texture_sizes != 0
          f.seek(@offset_texture_sizes)
          f.write(@texture_sizes.pack(t+"*"))
        end

        if @offset_texture_flags != 0
          f.seek(@offset_texture_flags)
          tex_flags = @texture_flags.dup
          if big
            tex_flags.map! { |e|
              e |= 0x2
              e
            }
          end
          f.write(tex_flags.pack(t+"*"))
        end

        if @offset_texture_offsets != 0 &&  @offset_texture_sizes != 0
          @texture_offsets.each_with_index { |off, i|
            f.seek(off)
            f.write( @texture_datas[i] )
          }
        end

        if @offset_texture_idx != 0
          f.seek(@offset_texture_idx)
          f.write( @texture_idx.pack(t+"*"))
        end
      }
    end

  end

  def self.extract_eff(filename, big=false)

    directory = File.dirname(filename)
    name = File.basename(filename)
    ext_name = File.extname(name)

    raise "Invalid file (#{name})!" unless ext_name == ".eff"

    f = File::new(filename, "rb")

    Dir.chdir(directory)
    dir_name = File.basename(name, ext_name)+"_eff"
    Dir.mkdir(dir_name) unless Dir.exist?(dir_name)
    Dir.chdir(dir_name)

    eff = EFFFile::new(f, big)

    eff.each_directory { |id, dir|
      d_name = ("%02d_"%id) + dir.name
      Dir.mkdir(d_name) unless Dir.exist?(d_name)
      dir.each { |fname, f2|
        File::open("#{d_name}/#{fname}", "wb") { |f3|
          f2.rewind
          f3.write(f2.read)
        }
      }
    }

    f.close
  end

end
