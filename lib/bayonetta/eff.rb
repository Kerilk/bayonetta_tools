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

      def initialize(f, big)
        @big = big
        if f
          @name = f.read(4)
          case @name
          when "EST\0".b, "SAD\0".b, "SST\0".b
            f.rewind
            @file_number = 1
            @file_infos = [[0, 0, f.size]]
            @files = [f]
            @extname = @name.delete("\x00").downcase
          when "TEX\0".b, "MOD\0".b
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
            if @name == "TEX\0".b
              @extname = "wtb"
            else
              @extname = "dat"
            end
          else
            raise "Unknown directory type: #{@name}!"
          end
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
        when "EST\0".b, "SAD\0".b, "SST\0".b
          raise "Unsupported file number #{@file_number}!" unless @file_number == 1
          @file_infos[0][1] = 0x0
          @file_infos[0][2]
        when "TEX\0".b, "MOD\0".b
          current_offset = 0x1000
          @file_infos = @file_infos.collect { |id, _, size|
            ret = [id, current_offset, size]
            current_offset += size
            current_offset = align(current_offset, 0x1000)
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
        str = StringIO::new("\x00"*total_size, "w+b")
        str.rewind

        case @name
        when "EST\0".b, "SAD\0".b, "SST\0".b
          f = @files[0]
          f.rewind
          str.write f.read
          f.rewind
        when "TEX\0".b, "MOD\0".b
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

    end

    def initialize(f = nil, big = false)
      @big = big
      if f
        uint = get_uint
        @id = f.read(4)
        raise "Invalid id #{@id.inspect}!" if @id != "EF2\0".b
        @directory_number = f.read(4).unpack(uint).first
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
          Directory::new(of, big)
        }
      else
        @id = "EF2\x00"
        @directory_number = 0
        @directory_infos = []
        @directories = []
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
      str = StringIO::new("\x00"*total_size, "w+b")
      str.rewind

      uint = get_uint

      str.write @id
      str.write [@directory_number].pack(uint)
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
