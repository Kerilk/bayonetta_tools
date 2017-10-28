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

end
