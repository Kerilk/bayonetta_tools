module Bayonetta

  class EXPFile < DataConverter

    class EXPFileHeader < DataConverter
      register_field :id, :c, count: 4
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
    end

    register_field :header, EXPFileHeader
    register_field :records, Record, count: 'header\num_records'
    register_field :entries, Entry, count: 'header\num_records', sequence: true,
      offset: 'records[__iterator]\offset'

    def convert(input, output, input_big, output_big, parent = nil, index = nil)
      set_convert_type(input, output, input_big, output_big, parent, index)
      convert_fields

#      if @header.num_records > 0
#        @records = @header.num_records.times.collect {
#          Record::convert(input, output, input_big, output_big)
#        }
#        @entries = @header.num_records.times.collect { |i|
#          entry = nil
#          if @records[i].offset > 0
#            input.seek(@records[i].offset)
#            output.seek(@records[i].offset)
#            case @records[i].entry_type
#            when 1
#              entry = Entry1::convert(input, output, input_big, output_big)
#            when 2
#              entry = Entry2::convert(input, output, input_big, output_big)
#            when 3
#              entry = Entry3::convert(input, output, input_big, output_big)
#            end
#          end
#          entry
#        }
#      end
    end

    def self.convert(input_name, output_name, input_big = true, output_big = false)
      input = File.open(input_name, "rb")
      id = input.read(4).unpack("a4").first
      raise "Invalid file type #{id}!" unless id == "exp\0".b
      output = File.open(output_name, "wb")
      output.write("\x00"*input.size)
      input.seek(0);
      output.seek(0);

      exp = self::new
      exp.convert(input, output, input_big, output_big)

      input.close
      output.close
    end

  end

end
