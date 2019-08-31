module Bayonetta

  class PKZFile < DataConverter

    class FileDescriptor < DataConverter
      uint64 :offset_name
      uint64 :size
      uint64 :offset
      uint64 :compressed_size
#      string :name, offset: 'offset_name + ..\header.offset_file_descriptors + ..\header.num_files * 0x20'
    end

    class Header < DataConverter
      uint32 :id
      int32  :unknown
      uint64 :size
      uint32 :num_files
      uint32 :offset_file_descriptors
      uint64 :length_file_name_table
    end

    register_field :header, Header
    register_field :file_descriptors, FileDescriptor, count: 'header.num_files',
                   offset: 'header.offset_file_descriptors'

    def self.is_big?(f)
      f.rewind
      block = lambda { |int64|
        id = f.read(4)
        raise "Invalid id #{id.inspect}!" if id != "pkzl".b
        f.read(4)
        size = f.read(8).unpack(int64).first
        size == f.size
      }
      big = block.call("q>")
      f.rewind
      small = block.call("q<")
      f.rewind
      raise "Invalid data!" unless big ^ small
      return big
    end

    def self.load(input_name)
      if input_name.respond_to?(:read) && input_name.respond_to?(:seek)
        input = input_name
      else
        input = File.open(input_name, "rb")
      end
      input_big = is_big?(input)
      pkz = self::new
      pkz.instance_variable_set(:@__was_big, input_big)
      pkz.load(input, input_big)
      input.close unless input_name.respond_to?(:read) && input_name.respond_to?(:seek)

      pkz
    end

  end

end
