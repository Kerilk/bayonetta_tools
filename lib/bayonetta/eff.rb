require 'stringio'

module Bayonetta

  class EFFFile
    include Endianness
    include Alignment

    class Directory
      include Endianness

      private :get_uint

      def initialize(id, f, big)
        if f
          @big = big
          @id = id
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

      def name
        return @name.delete("\x00")
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
          Directory::new(id, of, big)
        }
      else
        
      end

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
