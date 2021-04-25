require 'stringio'

module Bayonetta

  class EFFFile
    include Endianness
    include Alignment

    class Directory
      include Endianness
      include Alignment

      private :get_uint
      attr_accessor :file_number
      attr_accessor :file_infos
      attr_accessor :files
      attr_reader :big
      attr_reader :name

      EXTENSIONS = {
        "TEX\0".b => "wtb",
        "MOD\0".b => "dat"
      }
      ALIGNMENT = {
        "TEX\0".b => 0x1000,
        "MOD\0".b => 0x1000,
        "EST\0".b => 0x10,
        "IDT\0".b => 0x10
      }
      KNOWN_DIRECTORIES = [
        "SAD\0".b,
        "SST\0".b,
        "TUV\0".b,
        "TEX\0".b,
        "MOD\0".b,
        "EST\0".b
      ]
      KNOWN_STRUCTURE = [
        "TEX\0".b,
        "MOD\0".b,
        "EST\0".b,
        "IDT\0".b
      ]

      UNKNOWN_STRUCTURE = KNOWN_DIRECTORIES - KNOWN_STRUCTURE

      def initialize(f, big)
        @big = big
        if f
          @name = f.read(4)
          case @name
          when *UNKNOWN_STRUCTURE
            f.rewind
            @file_number = 1
            @file_infos = [[0, 0, f.size]]
            @files = [f]
          when *KNOWN_STRUCTURE
            uint = get_uint
            @file_number = f.read(4).unpack(uint).first
            @file_infos = @file_number.times.collect { |i|
              f.read(8).unpack("#{uint}2")
            }
            sorted_file_infos = @file_infos.sort { |e1, e2| e1[1] <=> e2[1] }
            sorted_file_infos.each_with_index { |info, i|
              id, offset = info
              if sorted_file_infos[i+1]
                size = sorted_file_infos[i+1][1] - offset
              else
                size = f.size - offset
              end
              info.push(size)
            }
            @files = @file_infos.collect { |id, offset, size|
              f.seek(offset)
              of = StringIO::new( f.read(size), "rb")
            }
          else
            raise "Unknown directory type: #{@name}!"
          end
          @extname = EXTENSIONS[@name]
          @extname = @name.delete("\x00").downcase unless @extname
        else
          @name = nil
          @file_number = 0
          @file_infos = []
          @files = []
        end
      end

      def each
        if block_given?
          @file_number.times { |i|
            yield ("%010d." % @file_infos[i][0])+@extname, @files[i]
          }
        else
          to_enum(:each)
        end
      end

      def push(id, f)
        f.rewind
        sz = f.size
        of = StringIO::new( f.read, "rb")
        @file_number += 1
        @files.push of
        @file_infos.push [id, nil, sz]
        self
      end

      def name
        @name.delete("\x00")
      end

      def name=(s)
        s = s + "\x00"
        @name = s
      end

      def compute_layout
        case @name
        when *UNKNOWN_STRUCTURE
          raise "Unsupported file number #{@file_number}!" unless @file_number == 1
          @file_infos[0][1] = 0x0
          @file_infos[0][2]
        when *KNOWN_STRUCTURE
          current_offset = align(4 + 4 + @file_infos.length * 8, ALIGNMENT[@name])
          @file_infos = @file_infos.collect { |id, _, size|
            ret = [id, current_offset, size]
            current_offset += size
            current_offset = align(current_offset, ALIGNMENT[@name])
            ret
          }
          current_offset
        else
          raise "Invalid directory #{@name}!"
        end
      end

      def size
        compute_layout
      end

      def to_stringio
        total_size = compute_layout
        str = StringIO::new("\x00".b*total_size, "w+b")
        str.rewind

        case @name
        when *UNKNOWN_STRUCTURE
          f = @files[0]
          f.rewind
          str.write f.read
          f.rewind
        when *KNOWN_STRUCTURE
          uint = get_uint
          str.write @name
          str.write [@file_number].pack(uint)
          @file_infos.each { |id, offset, _|
            str.write [id, offset].pack("#{uint}*")
          }
          @file_number.times { |i|
            str.seek(@file_infos[i][1])
            f = @files[i]
            f.rewind
            str.write f.read
            f.rewind
          }
        end
        str.rewind
        str.close_write
        str
      end

    end #Directory

    attr_reader :big
    attr_accessor :layout
    attr_accessor :id

    def self.check_id(id)
      raise "Invalid id #{id.inspect}!" unless id == "EF2\0".b || id == "IDD\0".b
    end

    def self.is_big?(f)
      f.rewind
      block = lambda { |int|
        id = f.read(4)
        self.check_id(id)
        directory_number = f.read(4).unpack(int).first
        if directory_number * 8 + 8 < f.size
          directory_infos = directory_number.times.collect {
            f.read(8).unpack("#{int}2")
          }
          ( directory_number >= 0 ) && directory_infos.reduce(true) { |memo, (index, offset)|
            memo && index >= 0 && offset > 0 && offset < f.size
          }
        else
          false
        end
      }
      big = block.call("l>")
      f.rewind
      small = block.call("l<")
      f.rewind
      raise "Invalid data!" unless big ^ small
      return big
    end

    def check_id
      EFFFile.check_id(@id)
    end

    def initialize(f = nil, big = false, id = "EF2\0".b)
      @big = big
      if f
        file_name_input = false
        unless f.respond_to?(:read) && f.respond_to?(:seek)
          file_name_input = true
          f = File::new(f, "rb")
        end
        @big = EFFFile.is_big?(f)
        uint = get_uint
        @id = f.read(4)
        check_id
        @directory_number = f.read(4).unpack(uint).first
        @directory_number += 1 if @id == "IDD\0".b
        @directory_infos = @directory_number.times.collect {
          f.read(8).unpack("#{uint}2")
        }
        sorted_directory_infos = @directory_infos.sort { |e1, e2| e1[1] <=> e2[1] }
        sorted_directory_infos.each_with_index { |info, i|
          id, offset = info
          if sorted_directory_infos[i+1]
            size = sorted_directory_infos[i+1][1] - offset
          else
            size = f.size - offset
          end
          info.push(size)
        }
        @directories = @directory_infos.collect { |id, offset, size|
          f.seek(offset)
          of = StringIO::new( f.read(size), "rb")
          Directory::new(of, @big)
        }
        @layout = @directories.each_with_index.collect { |d, i|
          [ @directory_infos[i][0] , d.name]
        }
      else
        @id = id
        @directory_number = 0
        @directory_infos = []
        @directories = []
        @layout = nil
      end

    end

    def push(id, d)
      @directories.push(d)
      @directory_infos.push [id, nil]
      @directory_number += 1
      self
    end

    def compute_layout
      current_offset = 0x1000
      @directory_number.times { |i|
        @directory_infos[i][1] = current_offset
        current_offset += @directories[i].size
        current_offset = align(current_offset, 0x1000)
      }
      current_offset
    end

    def to_stringio
      total_size = compute_layout
      str = StringIO::new("\x00".b*total_size, "w+b")
      str.rewind

      uint = get_uint

      str.write @id
      if @id == "IDD\0".b
        str.write [@directory_number-1].pack(uint)
      else
        str.write [@directory_number].pack(uint)
      end
      @directory_infos.each { |inf|
        str.write inf.pack("#{uint}*")
      }
      @directory_number.times { |i|
        str.seek(@directory_infos[i][1])
        f = @directories[i].to_stringio
        str.write f.read
      }

      str.rewind
      str.close_write
      str
    end

    def each_directory
      if block_given?
        @directory_number.times { |i|
          yield @directory_infos[i][0], @directories[i]
        }
      else
        to_enum(:each_directory)
      end
    end

  end

end
