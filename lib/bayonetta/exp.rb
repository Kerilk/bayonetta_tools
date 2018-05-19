module Bayonetta

  class EXPFile2 < DataConverter

    class EXPFileHeader < DataConverter
      int8 :id, count: 4
      int32 :version
      uint32 :offset_records
      uint32 :num_records
      uint32 :offset_interpolations
      uint32 :num_interpolations

      def initialize
        @id = "exp\0".b
        @version = 0x20110714
        @offset_records = 0
        @num_records = 0
        @offset_interpolations = 0
        @num_interpolations = 0
      end
    end

    class Record < DataConverter
      int16 :bone_number
      int8 :animation_track
      int8 :padding
      int16 :num_operations
      int16 :unknown
      uint32 :offset

      def initialize
        @bone_number = 0
        @animation_track = 0
        @padding = 0
        @num_operations = 0
        @unknown = 0
        @offset = 0
      end

    end

    class Operation < DataConverter
      int8 :type
      int8 :info
      int16 :number
      float :value

      def initialize
        @type = 0
        @info = 0
        @number = 0
        @value = 0.0
      end

    end

    class Entry < DataConverter
      register_field :operations, Operation, count: '..\records[__index]\num_operations'

      def initialize
        @operations = []
      end

    end

    class Interpolation < DataConverter
      int16 :num_points
      int16 :padding
      uint32 :offset

      def initialize
        @num_points = 0
        @padding = 0
        @offset = 0
      end

    end

    class Points < DataConverter
      float :v
      float :p
      float :m0
      float :m1

      def initialize
        @v = 0.0
        @p = 0.0
        @m0 = 0.0
        @m1 = 0.0
      end

    end

    class InterpolationEntry < DataConverter
      register_field :points, Points, count: '..\interpolations[__index]\num_points'
    end

    register_field :header, EXPFileHeader
    register_field :records, Record, count: 'header\num_records', offset: 'header\offset_records'
    register_field :entries, Entry, count: 'header\num_records', sequence: true,
      offset: 'records[__iterator]\offset + header\offset_records + 12*__iterator'
    register_field :interpolations, Interpolation, count: 'header\num_interpolations', offset: 'header\offset_interpolations'
    register_field :interpolation_entries, InterpolationEntry, count: 'header\num_interpolations', sequence: true,
      offset: 'interpolations[__iterator]\offset + header\offset_interpolations + 8*__iterator'

    def recompute_layout
      self
    end

    def was_big?
      @__was_big
    end

    def dump(output_name, output_big = false)
      if output_name.respond_to?(:write) && output_name.respond_to?(:seek)
        output = output_name
      else
        output = File.open(output_name, "wb")
      end
      output.rewind

      set_dump_type(output, output_big, nil, nil)
      dump_fields
      unset_dump_type
      output.close unless output_name.respond_to?(:write) && output_name.respond_to?(:seek)
      self
    end

  end

  class EXPFile < DataConverter

    class EXPFileHeader < DataConverter
      int8 :id, count: 4
      int32 :version
      uint32 :offset_records
      uint32 :num_records

      def initialize
        @id = "exp\0".b
        @version = 0
        @offset_records = 0
        @num_records = 0
      end

    end

    class Record < DataConverter
      int16 :u_a
      int16 :bone_index
      int8 :animation_track
      int8 :entry_type
      int8 :u_b
      int8 :u_c
      int32 :u_d
      uint32 :offset
      int32 :u_e

      def initialize
        @u_a = 0
        @bone_index = 0
        @animation_track = 0
        @entry_type = 0
        @u_b = 0
        @u_c = 0
        @u_d = 0
        @offset = 0
        @u_e = 0
      end

    end

    class Operation < DataConverter
      uint32 :flags
      float :value

      def initialize
        @flags = 0
        @value = 0.0
      end

    end

    class Entry1 < DataConverter
      uint32 :flags
      int16 :bone_index
      int8 :animation_track
      int8 :padding

      def initialize
        @flags = 0x80000001
        @bone_index = 0
        @animation_track = 0
        @padding = 0
      end

    end

    class Entry2 < DataConverter
      uint32 :flags
      int16 :bone_index
      int8 :animation_track
      int8 :padding
      register_field :operation, Operation

      def initialize
        @flags = 0x80000001
        @bone_index = 0
        @animation_track = 0
        @padding = 0
        @operation = Operation::new
      end

    end

    class Entry3 < DataConverter
      uint32 :flags
      int16 :bone_index
      int8 :animation_track
      int8 :padding
      register_field :operations, Operation, count: 2

      def initialize
        @flags = 0x80000001
        @bone_index = 0
        @animation_track = 0
        @padding = 0
        @operations = [Operation::new, Operation::new]
      end

    end

    class Entry < DataConverter

      def self.convert(input, output, input_big, output_big, parent, index)
        entry_type = parent.records[index].entry_type
        entry = nil
        case entry_type
        when 1
          entry = Entry1::convert(input, output, input_big, output_big)
        when 2
          entry = Entry2::convert(input, output, input_big, output_big)
        when 3
          entry = Entry3::convert(input, output, input_big, output_big)
        end
        entry
      end

      def self.load(input, input_big, parent, index)
        entry_type = parent.records[index].entry_type
        entry = nil
        case entry_type
        when 1
          entry = Entry1::load(input, input_big, parent, index)
        when 2
          entry = Entry2::load(input, input_big, parent, index)
        when 3
          entry = Entry3::load(input, input_big, parent, index)
        end
        entry
      end

    end

    register_field :header, EXPFileHeader
    register_field :records, Record, count: 'header\num_records', offset: 'header\offset_records'
    register_field :entries, Entry, count: 'header\num_records', sequence: true,
      offset: 'records[__iterator]\offset'

    def convert(input, output, input_big, output_big, parent = nil, index = nil)
      set_convert_type(input, output, input_big, output_big, parent, index)
      convert_fields
    end

    def was_big?
      @__was_big
    end

    def add_entries(hash)
      hash.each { |k, v|
        raise "Invalid entry type #{k}!" if k>3 || k<1
        v.times {
          r = Record::new
          r.entry_type = k
          r.u_c = -1
          @records.insert(-2, r)
          case k
          when 1
            entry = Entry1::new
          when 2
            entry = Entry2::new
          when 3
            entry = Entry3::new
          end
          @entries.insert(-2, entry)
        }
      }
      self
    end

    def recompute_layout
      @header.num_records = @records.length
      last_offset = @header.offset_records
      last_offset += @records.collect(&:size).reduce(:+)

      table = @records.zip(entries).to_h
      reverse_table = table.invert

      @records.sort_by! { |r| [r.bone_index, r.animation_track] }
      @entries.sort_by! { |e| e ? [e.bone_index, e.animation_track] : [32767, -1] }
      
      @entries.each { |e|
        if e
          reverse_table[e].offset = last_offset
          last_offset += e.size
        else
          reverse_table[e].offset = 0
        end
      }
      @entries = @records.collect { |r| table[r] }
      self
    end

    def self.is_big?(f)
      f.rewind
      block = lambda { |int|
        id = f.read(4)
        raise "Invalid id #{id.inspect}!" if id != "exp\0".b
        u_a = f.read(4).unpack(int).first
        offset_record = f.read(4).unpack(int).first
        num_record = f.read(4).unpack(int).first

        num_record >= 0 && offset_record > 0 && offset_record < f.size
      }
      big = block.call("l>")
      f.rewind
      small = block.call("l<")
      f.rewind
      raise "Invalid data!" unless big ^ small
      return big
    end

    def self.is_bayo2?(f, big)
      f.rewind
      id = f.read(4)
      uint = "L<"
      uint = "L>" if big
      version = f.read(4).unpack(uint).first
      f.rewind
      return version == 0x20110714
    end

    def self.convert(input_name, output_name, input_big = true, output_big = false)
      input = File.open(input_name, "rb")
      id = input.read(4).unpack("a4").first
      raise "Invalid file type #{id}!" unless id == "exp\0".b
      output = File.open(output_name, "wb")
      output.write("\x00"*input.size)
      input.seek(0);
      output.seek(0);

      if is_bayo2?(input, input_big)
        exp = EXPFile2::new
      else
        exp = self::new
      end
      exp.convert(input, output, input_big, output_big)

      input.close
      output.close
    end

    def self.load(input_name)
      if input_name.respond_to?(:read) && input_name.respond_to?(:seek)
        input = input_name
      else
        input = File.open(input_name, "rb")
      end
      input_big = is_big?(input)

      if is_bayo2?(input, input_big)
        exp = EXPFile2::new
      else
        exp = self::new
      end
      exp.instance_variable_set(:@__was_big, input_big)
      exp.load(input, input_big)
      input.close unless input_name.respond_to?(:read) && input_name.respond_to?(:seek)

      exp
    end

    def dump(output_name, output_big = false)
      if output_name.respond_to?(:write) && output_name.respond_to?(:seek)
        output = output_name
      else
        output = File.open(output_name, "wb")
      end
      output.rewind

      set_dump_type(output, output_big, nil, nil)
      dump_fields
      unset_dump_type
      output.close unless output_name.respond_to?(:write) && output_name.respond_to?(:seek)
      self
    end

  end

end
