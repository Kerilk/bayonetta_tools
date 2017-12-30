require 'stringio'
require 'zlib'

module Bayonetta

  class WTBFile
    include Endianness

    attr_accessor :unknown
    attr_accessor :texture_flags
    attr_accessor :texture_idx
    attr_accessor :texture_infos
    attr_reader :big
    ALIGNMENTS = {
      '.dds' => 0x1000,
      '.gtx' => 0x2000,
    }
    ALIGNMENTS.default = 0x20

  
    def initialize(f = nil, big = false, wtp = nil)
      if f
        f.rewind
        @wtp = wtp
        @id = f.read(4)
        case @id
        when "WTB\0".b
          texture_type = ".dds"
          @big = false
        when "\0BTW".b
          texture_type = ".gtx"
          @big = true
        else
          "Invalid file type #{@id}!"
        end
        uint = get_uint
        @total_size = f.size
        @unknown = f.read(4).unpack(uint).first
        @num_tex = f.read(4).unpack(uint).first
        @offset_texture_offsets = f.read(4).unpack(uint).first
        @offset_texture_sizes = f.read(4).unpack(uint).first
        @offset_texture_flags = f.read(4).unpack(uint).first
        @offset_texture_idx = f.read(4).unpack(uint).first
        @offset_texture_infos = f.read(4).unpack(uint).first
        if @wtp && @big
          @offset_mipmap_offsets = f.read(4).unpack(uint).first
          if @offset_mipmap_offsets != 0
            f.seek(@offset_mipmap_offsets)
            @mipmap_offsets = f.read(4*@num_tex).unpack("#{uint}*")
          end
        end

        f.seek(@offset_texture_offsets)
        @texture_offsets = f.read(4*@num_tex).unpack("#{uint}*")

        if @offset_texture_sizes != 0
          f.seek(@offset_texture_sizes)
          @texture_sizes = f.read(4*@num_tex).unpack("#{uint}*")
        end

        if @offset_texture_flags != 0
          f.seek(@offset_texture_flags)
          @texture_flags = f.read(4*@num_tex).unpack("#{uint}*")
        end

        if @offset_texture_idx != 0
          f.seek(@offset_texture_idx)
          @texture_idx = f.read(4*@num_tex).unpack("#{uint}*")
        else
          @texture_idx = []
        end

        @texture_infos = []

        if !@wtp && @offset_texture_offsets != 0 && @offset_texture_sizes != 0
          @textures = @texture_offsets.each_with_index.collect { |off, i|
            f.seek( off )
            StringIO::new( f.read( @texture_sizes[i] ), "rb" )
          }
        elsif @wtp && @big && @offset_texture_offsets != 0 && @offset_texture_sizes != 0 # Bayo 2 WiiU
          @wtp.rewind
          @data_length = []
          @mipmap_length = []
          @textures = @texture_offsets.each_with_index.collect { |off, i|
            of = StringIO::new("", "w+b")
            f.seek(@offset_texture_infos + i*0xc0)
            gx2 = f.read(0x9c)
            num_mipmap = gx2[0x10...0x14].unpack(uint).first
            data_length = gx2[0x20...0x24].unpack(uint).first
            mipmap_length = gx2[0x28...0x2c].unpack(uint).first
            @data_length.push data_length
            @mipmap_length.push mipmap_length
            of.write("\x47\x66\x78\x32\x00\x00\x00\x20\x00\x00\x00\x07\x00\x00\x00\x01\x00\x00\x00\x02\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00")
            of.write("\x42\x4C\x4B\x7B\x00\x00\x00\x20\x00\x00\x00\x01\x00\x00\x00\x00\x00\x00\x00\x0B\x00\x00\x00\x9C\x00\x00\x00\x00\x00\x00\x00\x00")
            of.write(gx2)
            of.write("\x42\x4C\x4B\x7B\x00\x00\x00\x20\x00\x00\x00\x01\x00\x00\x00\x00\x00\x00\x00\x0C")
            of.write(gx2[0x20...0x24])
            of.write("\x00\x00\x00\x00\x00\x00\x00\x00")
            @wtp.seek(off)
            of.write( @wtp.read(data_length) )
            if num_mipmap > 1
              of.write("\x42\x4C\x4B\x7B\x00\x00\x00\x20\x00\x00\x00\x01\x00\x00\x00\x00\x00\x00\x00\x0D")
              of.write(gx2[0x28...0x2c])
              of.write("\x00\x00\x00\x00\x00\x00\x00\x00")
              @wtp.seek(@mipmap_offsets[i])
              of.write( @wtp.read(mipmap_length) )
            end
            of.write("\x42\x4C\x4B\x7B\x00\x00\x00\x20\x00\x00\x00\x01\x00\x00\x00\x00\x00\x00\x00\x01\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00")
            of.close_write
            of
          }
          @wtp = true
	elsif @wtp && !@big && @offset_texture_offsets != 0 && @offset_texture_sizes != 0 # Nier PC
          @wtp.rewind
          @textures = @texture_offsets.each_with_index.collect { |off, i|
            of = StringIO::new("", "w+b")
            @wtp.seek(off)
            of.write( @wtp.read(@texture_sizes[i]) )
            of.close_write
            of
          }
          if @offset_texture_infos != 0
            f.seek(@offset_texture_infos)
            @texture_infos = f.read(5*4*@num_tex).unpack("#{uint}*")
          end
        else
          raise "Invalid texture data!"
        end

        @texture_types = [texture_type]*@num_tex

      else
        @big = big
        @wtp = wtp
        @id = "WTB\0".b
        @id.reverse! if @big
        @unknown = 0x1
        @num_tex = 0
        @offset_texture_offsets = 0x0
        @offset_texture_sizes = 0x0
        @offset_texture_flags = 0x0
        @offset_texture_idx = 0x0
        @offset_texture_infos = 0x0
        if @wtp && @big
          @offset_mipmap_offsets = 0x0
          @mipmap_offsets = []
          @mipmap_length = []
          @data_length = []
        end

        @texture_offsets = []
        @texture_sizes = []
        @texture_flags = []
        @texture_idx = []
        @texture_infos = []

        @textures = []
        @texture_types = []
      end
    end

    def invalidate_layout
      @offset_texture_offsets = 0x0
      @offset_texture_sizes = 0x0
      @offset_texture_flags = 0x0
      @offset_texture_idx = 0x0
      @offset_texture_infos = 0x0
      if @wtp && @big
        @offset_mipmap_offsets = 0x0
        @mipmap_offsets = []
      end
      @texture_offsets = []
    end

    def compute_layout
      if @wtp && @big
        last_offset = @offset_texture_offsets = 0x40
      else
        last_offset = @offset_texture_offsets = 0x20
      end
      last_offset = @offset_texture_sizes = align(last_offset + 4*@num_tex, 0x20)
      last_offset = @offset_texture_flags = align(last_offset + 4*@num_tex, 0x20)
      if @texture_idx != []
        last_offset = @offset_texture_idx = align(last_offset + 4*@num_tex, 0x20)
      end
      unless @wtp
        @texture_offsets = @num_tex.times.collect { |i|
          tmp = align(last_offset, ALIGNMENTS[@texture_types[i]])
          last_offset = align(tmp + @texture_sizes[i], ALIGNMENTS[@texture_types[i]])
          tmp
        }
        @total_size = last_offset
      else
        last_offset = @offset_texture_infos = align(last_offset + 4*@num_tex, 0x20)
        if @big
          last_offset = @offset_mipmap_offsets = align(last_offset + 0xc0*@num_tex, 0x20)
          last_offset = align(last_offset + 4*@num_tex, 0x20)
        else #Nier
          last_offset = align(last_offset + 5*4*@num_tex, 0x20)
        end
        @total_size = last_offset

        offset_wtp = 0x0
        if @big
          @texture_offsets = @num_tex.times.collect { |i|
            tmp = align(offset_wtp, ALIGNMENTS[@texture_types[i]])
            offset_wtp = align(tmp + @data_length[i], ALIGNMENTS[@texture_types[i]])
            tmp
          }
          @mipmap_offsets = @num_tex.times.collect { |i|
            if @mipmap_length[i] != 0
              tmp = align(offset_wtp, ALIGNMENTS[@texture_types[i]])
              offset_wtp = align(tmp + @mipmap_length[i], ALIGNMENTS[@texture_types[i]])
              tmp
            else
              0
            end
          }
        else #Nier
          @texture_offsets = @num_tex.times.collect { |i|
            tmp = align(offset_wtp, ALIGNMENTS[@texture_types[i]])
            offset_wtp = align(tmp + @texture_sizes[i], ALIGNMENTS[@texture_types[i]])
            tmp
          }
        end
        @total_size_wtp = offset_wtp
      end
    end

    def push(file, flag = 0x0, idx = nil)
      id = file.read(4)
      file.rewind
      case id
      when "Gfx2".b
        @texture_types.push( ".gtx" )
      when "DDS ".b
        @texture_types.push( ".dds" )
      else
        raise "Unsupported texture type! #{id}"
      end
      invalidate_layout
      uint = get_uint
      flag = 0x60000020 if @wtp && flag == 0x0
      @texture_sizes.push( file.size )
      @textures.push( file )
      @texture_flags.push( flag )
      @texture_idx.push if idx
      if @wtp && @big
        unless idx
          @texture_idx.push Zlib.crc32(file.read,0)
          file.rewind
        end
        file.seek(0x20*2)
        gx2 = file.read(0x9c)
        num_mipmap = gx2[0x10...0x14].unpack(uint).first
        data_length = gx2[0x20...0x24].unpack(uint).first
        mipmap_length = gx2[0x28...0x2c].unpack(uint).first
        @data_length.push( data_length )
        if num_mipmap > 1
          @mipmap_length.push( mipmap_length )
        else
          @mipmap_length.push( 0x0 )
        end
      end
      @num_tex += 1
      self
    end

    def each
      if block_given? then
        @num_tex.times { |i|
          yield [@texture_types[i], @texture_flags[i], @texture_idx[i]], @textures[i]
        }
      else
        to_enum(:each)
      end
    end

    def dump(name)
      compute_layout
      uint = get_uint
      File.open(name,"wb") { |f|
        f.write("\0"*@total_size)
        f.rewind
        f.write(@id)
        f.write([@unknown].pack(uint))
        f.write([@num_tex].pack(uint))
        f.write([@offset_texture_offsets].pack(uint))
        f.write([@offset_texture_sizes].pack(uint))
        f.write([@offset_texture_flags].pack(uint))
        f.write([@offset_texture_idx].pack(uint))
        f.write([@offset_texture_infos].pack(uint))
        f.write([@offset_mipmap_offsets].pack(uint)) if @wtp && @big


        f.seek(@offset_texture_offsets)
        f.write(@texture_offsets.pack("#{uint}*"))

        if @offset_texture_sizes != 0
          f.seek(@offset_texture_sizes)
          f.write(@texture_sizes.pack("#{uint}*"))
        end

        if @offset_texture_flags != 0
          f.seek(@offset_texture_flags)
          f.write(@texture_flags.pack("#{uint}*"))
        end

        if @offset_texture_idx != 0
          f.seek(@offset_texture_idx)
          f.write(@texture_idx.pack("#{uint}*"))
        end

        unless @wtp
          @texture_offsets.each_with_index { |off, i|
            f.seek(off)
            @textures[i].rewind
            f.write( @textures[i].read )
            @textures[i].rewind
          }
        else
          if @big
            @textures.each_with_index { |f_t, i|
              f.seek(@offset_texture_infos + i*0xc0)
              f_t.seek(0x20*2)
              f.write( f_t.read(0x9c) )
            }
            if @offset_mipmap_offsets != 0
              f.seek(@offset_mipmap_offsets)
              f.write(@mipmap_offsets.pack("#{uint}*"))
            end
          else #Nier
            if @offset_texture_infos != 0
              f.seek(@offset_texture_infos)
              f.write(@texture_infos.pack("#{uint}*"))
            end
          end
          File.open(name.gsub(".wta", ".wtp"), "wb") { |f_wtp|
            f_wtp.write("\x00"*@total_size_wtp)
            f_wtp.rewind
            if @big
              @texture_offsets.each_with_index { |off, i|
                f_wtp.seek(off)
                @textures[i].seek(0x20*3+0x9c)
                f_wtp.write(@textures[i].read(@data_length[i]))
              }
              @mipmap_offsets.each_with_index { |off, i|
                if off != 0
                  f_wtp.seek(off)
                  @textures[i].seek(0x20*4+0x9c+@data_length[i])
                  f_wtp.write(@textures[i].read(@mipmap_length[i]))
                end
              }
            else #Nier
              @texture_offsets.each_with_index { |off, i|
                f_wtp.seek(off)
                @textures[i].rewind
                f_wtp.write( @textures[i].read )
                @textures[i].rewind
              }
            end
          }
        end

      }

    end

  end

end
