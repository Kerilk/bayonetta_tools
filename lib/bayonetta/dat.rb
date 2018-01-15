require 'stringio'
module Bayonetta
  class DATFile
    include Endianness
    include Alignment
    attr_reader :big

    ALIGNMENTS = {
      'wmb' => 0x1000,
      'wtb' => 0x1000,
      'exp' => 0x1000,
      'eff' => 0x1000,
      'sdx' => 0x1000
    }
    ALIGNMENTS.default = 0x10

    def layout
      @layout
    end

    def layout=(l)
      @layout = l
    end

    def self.is_big?(f)
      f.rewind
      block = lambda { |int|
        id = f.read(4)
        raise "Invalid id #{id.inspect}!" if id != "DAT\0".b
        file_number = f.read(4).unpack(int).first
        file_offsets_offset = f.read(4).unpack(int).first
        file_extensions_offset = f.read(4).unpack(int).first
        file_names_offset = f.read(4).unpack(int).first
        file_sizes_offset = f.read(4).unpack(int).first

        ( file_number >= 0 ) &&
        ( file_offsets_offset > 0 ) && ( file_offsets_offset < f.size ) &&
        ( file_extensions_offset > 0 ) && ( file_extensions_offset < f.size ) &&
        ( file_names_offset > 0 ) && ( file_names_offset < f.size - 4 ) &&
        ( file_sizes_offset > 0 ) && ( file_sizes_offset < f.size )
      }
      big = block.call("l>")
      f.rewind
      small = block.call("l<")
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
        @big = DATFile.is_big?(f)

        f.rewind
        uint = get_uint
        @id = f.read(4)
        raise "Invalid id #{id.inspect}!" if @id != "DAT\0".b
        @file_number = f.read(4).unpack(uint).first
        @file_offsets_offset = f.read(4).unpack(uint).first
        @file_extensions_offset = f.read(4).unpack(uint).first
        @file_names_offset = f.read(4).unpack(uint).first
        @file_sizes_offset = f.read(4).unpack(uint).first

        f.seek(@file_offsets_offset)
        @file_offsets = f.read(4*@file_number).unpack("#{uint}*")
        f.seek(@file_extensions_offset)
        @file_extensions = @file_number.times.collect {
          f.read(3).unpack("a#{3}").first
        }

        f.seek(@file_names_offset)
        @filename_length = f.read(4).unpack(uint).first
        @file_names = @file_number.times.collect {
          f.read(@filename_length).unpack("a#{@filename_length}").first.delete("\0")
        }

        f.seek(@file_sizes_offset)
        @file_sizes = f.read(4*@file_number).unpack("#{uint}*")

        @files = @file_number.times.collect { |i|
          f.seek(@file_offsets[i])
          of = StringIO::new( f.read(@file_sizes[i]), "rb")
        }
        f.close if file_name_input
        @layout = @file_names.dup
      else
        @id = "DAT\x00".b
        @layout = nil
        @file_number = 0
        @file_offsets_offset = 0
        @file_extensions_offset = 0
        @file_names_offset = 0
        @file_sizes_offset = 0

        @file_offsets = []
        @file_extensions = []
        @filename_length = 0
        @file_names = []
        @file_sizes = []
        @files = []

      end
    end

    def each
      if block_given? then
        @file_number.times { |i|
          yield @file_names[i], @files[i]
        }
      else
        to_enum(:each)
      end
    end

    def [](i)
      return [@file_names[i], @files[i]]
    end

    def invalidate_layout
      @file_offsets_offset = 0
      @file_extensions_offset = 0
      @file_names_offset = 0
      @file_sizes_offset = 0
      @file_offsets = []
      @layout = nil
      self
    end

    def push(name, file)
      invalidate_layout
      @file_names.push name
      @files.push file
      @file_sizes.push file.size
      extname = File.extname(name)
      raise "Invalid name, missing extension!" if extname == ""
      @file_extensions.push extname[1..-1]
      @file_number += 1
      self
    end

    def sort_files
      if @layout
        file_map = @layout.each_with_index.collect.to_h
        all_arr = @files.zip( @file_names, @file_sizes, @file_extensions )
        all_arr.select! { |e|
          @layout.include?(e[1])
        }
        @file_number = all_arr.size
        all_arr.sort! { |e1, e2|
          file_map[e1[1]] <=> file_map[e2[1]]
        }
      else
        all_arr = @files.zip( @file_names, @file_sizes, @file_extensions )
        all_arr.sort! { |e1, e2|
          ALIGNMENTS[e2[3]] <=>  ALIGNMENTS[e1[3]]
        }
      end
      @files, @file_names, @file_sizes, @file_extensions = all_arr.transpose
      @layout = @file_names.dup unless @layout
    end

    def compute_layout
      sort_files

      @file_offsets_offset = 0x20
      @file_extensions_offset = @file_offsets_offset + 4 * @file_number
      @file_names_offset = @file_extensions_offset + 4 * @file_number
      max_file_name_length = @file_names.collect(&:length).max
      @file_name_length = max_file_name_length + 1
      @file_sizes_offset = @file_names_offset + 4 + @file_name_length * @file_number
      @file_sizes_offset = align(@file_sizes_offset, 4)
      files_offset = @file_sizes_offset + 4 * @file_number
      @files_offsets = @file_number.times.collect { |i|
        tmp = align(files_offset, ALIGNMENTS[@file_extensions[i]])
        files_offset = align(tmp + @file_sizes[i], ALIGNMENTS[@file_extensions[i]])
        tmp
      }
      @total_size = align(files_offset, 0x1000)
      self
    end

    def dump(name)
      compute_layout
      uint = get_uint
      File.open(name,"wb") { |f|
        f.write("\0"*@total_size)
        f.rewind
        f.write([@id].pack("a4"))
        f.write([@file_number].pack(uint))
        f.write([@file_offsets_offset].pack(uint))
        f.write([@file_extensions_offset].pack(uint))
        f.write([@file_names_offset].pack(uint))
        f.write([@file_sizes_offset].pack(uint))

        f.seek(@file_offsets_offset)
        f.write(@files_offsets.pack("#{uint}*"))

        f.seek(@file_extensions_offset)
        @file_extensions.each { |ext|
          f.write([ext].pack("a4"))
        }

        f.seek(@file_names_offset)
        f.write([@file_name_length].pack(uint))
        @file_names.each { |name|
          f.write([name].pack("a#{@file_name_length}"))
        }

        f.seek(@file_sizes_offset)
        f.write(@file_sizes.pack("#{uint}*"))

        @files_offsets.each_with_index { |off, i|
          f.seek(off)
          @files[i].rewind
          f.write( @files[i].read )
        }
      }
    end

  end

end
