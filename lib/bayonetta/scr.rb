module Bayonetta
  class SCR2File
    include Alignment
    include Endianness
    attr_reader :big
    attr_accessor :unknown
    attr_accessor :models_metadata

    ALIGNMENTS = {
      'wmb' => 0x80,
    }

    def bayo2?
      true
    end

    def self.is_bayo?(f)
      f.rewind
      id = f.read(4)
      raise "Invalid id #{id.inspect}!" if id != "SCR\0".b
      a, b = f.read(4).unpack("S2")
      f.rewind
      a == 0 || b == 0
    end

    def self.is_big?(f)
      f.rewind
      block = lambda { |int, short|
        id = f.read(4)
        raise "Invalid id #{id.inspect}!" if id != "SCR\0".b
        unknown = f.read(2).unpack(short).first
        model_number = f.read(2).unpack(short).first
        offset_model_offsets = f.read(4).unpack(int).first
        unknown >= 0 && model_number >=0 && (model_number * 0x8c + 0x10) < f.size &&
          offset_model_offsets >= 0 && offset_model_offsets < f.size
      }
      big = block.call("l>", "s>")
      f.rewind
      small = block.call("l<", "s<")
      f.rewind
      raise "Invalid data!" unless big ^ small
      return big
    end

    def initialize(f = nil, big = false)
      @big = big
      if f
        file_name_input = false
        unless f.respond_to?(:read) && f.respond_to?(:seek)
          file_name_input = true
          f = File::new(f, "rb")
        end
        @big = SCR2File.is_big?(f)

        f.rewind
        uint = get_uint
        ushort = get_ushort
        float = get_float
        short = get_short

        @id = f.read(4)
        raise "Invalid id #{id.inspect}!" if @id != "SCR\0".b
        @unknown, @num_models = f.read(4).unpack("#{ushort}2")
        @offset_offsets_models = f.read(4).unpack(uint).first

        f.seek(@offset_offsets_models)
        @offsets_models_meta = f.read(4*@num_models).unpack("#{uint}#{@num_models}")
        @offsets_models = []
        @sizes_models = []


        @models_metadata = @num_models.times.collect { |i|
          f.seek(@offsets_models_meta[i])
          offset = f.read(4).unpack(uint).first
          name = f.read(64)
          transform = f.read(4*9).unpack("#{float}9")
          u_a = f.read(18*2).unpack("#{short}18")
          @offsets_models.push(offset)
          {
            name: name,
            transform: transform,
            u_a: u_a
          }
        }
        @num_models.times { |i|
          if i == ( @num_models - 1 )
            @sizes_models.push( f.size - @offsets_models[i] )
          else
            @sizes_models.push( @offsets_models_meta[i+1] - @offsets_models[i] )
          end
        }
        @models = @num_models.times.collect { |i|
          f.seek(@offsets_models[i])
          StringIO::new( f.read(@sizes_models[i]), "rb")
        }
        @total_size = f.size
        f.close if file_name_input
      else
        @id = "SCR\0".b
        @unknown = 0x12
        @num_models = 0
        @offsets_models = []
        @sizes_models = []
        @models_metadata = []
        @offsets_models_meta = []
        @models = []
        @total_size = 0
        @offset_offsets_models = 0x10
      end
    end

    def each_model
      if block_given? then
        @num_models.times { |i|
          yield @models[i]
        }
      else
        to_enum(:each_model)
      end
    end

    def [](i)
      return @models[i]
    end

    def invalidate_layout
      @offsets_models = []
      @offsets_models_meta = []
      @total_size = 0
      self
    end

    def compute_layout
      invalidate_layout
      current_offset = @offset_offsets_models + 0x4 * @num_models
      @num_models.times { |i|
         current_offset = align(current_offset, 0x20)
         @offsets_models_meta.push(current_offset)
         current_offset += 0x8c
         current_offset = align(current_offset, ALIGNMENTS["wmb"])
         @offsets_models.push(current_offset)
         current_offset += @sizes_models[i]
      }
      @total_size = align(current_offset, 0x20)
      self
    end

    def push_model(file)
      invalidate_layout
      @models.push file
      @sizes_models.push file.size
      @num_models += 1
      self
    end

    def textures
      nil
    end

    def dump(name)
      compute_layout
      uint = get_uint
      ushort = get_ushort
      File.open(name,"wb") { |f|
        f.write("\0"*@total_size)
        f.rewind
        f.write([@id].pack("a4"))
        f.write([@unknown].pack(ushort))
        f.write([@num_models].pack(ushort))
        f.write([@offset_offsets_models].pack(uint))
        f.seek(@offset_offsets_models)
        f.write(@offsets_models_meta.pack("#{uint}#{@num_models}"))
        @num_models.times { |i|
          f.seek(@offsets_models_meta[i])
          f.write([@offsets_models[i]].pack(uint))
          f.write([@models_metadata[i][:name]].pack("a64"))
          f.write(@models_metadata[i][:transform].pack("#{get_float}9"))
          f.write(@models_metadata[i][:u_a].pack("#{get_short}18"))
          f.seek(@offsets_models[i])
          @models[i].rewind
          f.write(@models[i].read)
        }
      }
      self
    end

  end

  class SCRFile
    include Alignment
    include Endianness
    attr_reader :big
    attr_accessor :unknown
    attr_accessor :models_metadata

    ALIGNMENTS = {
      'wmb' => 0x20,
      'wtb' => 0x1000,
    }

    def bayo2?
      false
    end

    def self.is_big?(f)
      f.rewind
      block = lambda { |int|
        id = f.read(4)
        raise "Invalid id #{id.inspect}!" if id != "SCR\0".b
        model_number = f.read(4).unpack(int).first
        offset_texture = f.read(4).unpack(int).first
        ( model_number >= 0 ) && ( (model_number * 0x8c + 0x10) < f.size  ) && ( offset_texture >= 0 ) && ( offset_texture < f.size )
      }
      big = block.call("l>")
      f.rewind
      small = block.call("l<")
      f.rewind
      raise "Invalid data!" unless big ^ small
      return big
    end

    def self.is_bayo2?(f)
      f.rewind
      id = f.read(4)
      raise "Invalid id #{id.inspect}!" if id != "SCR\0".b
      a, b = f.read(4).unpack("S2")
      f.rewind
      a > 0 && b > 0
    end

    def self.load(f)
      file_name_input = false
      unless f.respond_to?(:read) && f.respond_to?(:seek)
        f = File::new(f, "rb")
        file_name_input = true
      end
      if is_bayo2?(f)
        scr = SCR2File::new(f)
      else
        scr = SCRFile::new(f)
      end
      f.close if file_name_input
      scr
    end

    def initialize(f = nil, big = false)
      @big = big
      if f
        file_name_input = false
        unless f.respond_to?(:read) && f.respond_to?(:seek)
          file_name_input = true
          f = File::new(f, "rb")
        end
        @big = SCRFile.is_big?(f)

        f.rewind
        uint = get_uint

        @id = f.read(4)
        raise "Invalid id #{id.inspect}!" if @id != "SCR\0".b
        @num_models = f.read(4).unpack(uint).first
        @offset_texture = f.read(4).unpack(uint).first
        @unknown = f.read(4)
        flt = get_float
        sh = get_short
        @offsets_models = []
        @sizes_models = []
        @models_metadata = @num_models.times.collect {
          pos = f.tell
          name = f.read(16)
          offset = f.read(4).unpack(uint).first
          transform = f.read(4*9).unpack("#{flt}9")
          u_a = f.read(42*2).unpack("#{sh}42")
          @offsets_models.push(pos + offset)
          {
            name: name,
            transform: transform,
            u_a: u_a
          }
        }
        @num_models.times { |i|
          if i == ( @num_models - 1 )
            @sizes_models.push( @offset_texture - @offsets_models[i] )
          else
            @sizes_models.push( @offsets_models[i+1] - @offsets_models[i] )
          end
        }
        @size_textures = f.size - @offset_texture
        @models = @num_models.times.collect { |i|
          f.seek(@offsets_models[i])
          StringIO::new( f.read(@sizes_models[i]), "rb")
        }
        f.seek(@offset_texture)
        @textures = StringIO::new( f.read(@size_textures), "rb")
        @total_size = f.size
        f.close if file_name_input
      else
        @id = "SCR\0".b
        @num_models = 0
        @offset_texture = 0
        @size_textures = 0
        @unknown = "\1\0\0\0".b
        @offsets_models = []
        @sizes_models = []
        @models_metadata = []
        @models = []
        @textures = nil
        @total_size = 0
      end
    end

    def each_model
      if block_given? then
        @num_models.times { |i|
          yield @models[i]
        }
      else
        to_enum(:each_model)
      end
    end

    def [](i)
      return @models[i]
    end

    def invalidate_layout
      @offsets_models = []
      @offset_texture = 0
      @total_size = 0
      self
    end

    def compute_layout
      current_offset = 0x10 + 0x8c * @num_models
      @offsets_models = @num_models.times.collect { |i|
         tmp = align(current_offset, ALIGNMENTS["wmb"])
         current_offset = tmp + @sizes_models[i]
         tmp
      }
      @offset_texture = align(current_offset, ALIGNMENTS["wtb"])
      @total_size = @offset_texture + @size_textures
      self
    end

    def push_model(file)
      invalidate_layout
      @models.push file
      @sizes_models.push file.size
      @num_models += 1
      self
    end

    def textures=(file)
      invalidate_layout
      @textures = file
      @size_textures = file.size
      self
    end

    def textures
      @textures
    end

    def dump(name)
      compute_layout
      uint = get_uint
      File.open(name,"wb") { |f|
        f.write("\0"*@total_size)
        f.rewind
        f.write([@id].pack("a4"))
        f.write([@num_models].pack(uint))
        f.write([@offset_texture].pack(uint))
        f.write([@unknown].pack("a4"))
        @num_models.times { |i|
          pos = f.tell
          f.write([@models_metadata[i][:name]].pack("a16"))
          f.write([@offsets_models[i] - pos].pack(uint))
          f.write(@models_metadata[i][:transform].pack("#{get_float}9"))
          f.write(@models_metadata[i][:u_a].pack("#{get_short}42"))
        }
        @offsets_models.each_with_index { |off, i|
          f.seek(off)
          @models[i].rewind
          f.write(@models[i].read)
        }
        f.seek(@offset_texture)
        @textures.rewind
        f.write(@textures.read)
      }
      self
    end
  end
end
