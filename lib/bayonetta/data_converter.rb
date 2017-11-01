module Bayonetta

  class DataConverter
    DATA_SIZES = {
      :c => 1,
      :C => 1,
      :s => 2,
      :S => 2,
      :l => 4,
      :L => 4
    }
    def set_convert_type(input, output, input_big, output_big)
      @input_big = input_big
      @output_big = output_big
      @input = input
      @output = output
    end

    def self.inherited(subclass)
      subclass.instance_variable_set(:@fields, [])
    end

    def self.register_field(field, type, count = 1)
      @fields.push([field, type, count])
      attr_accessor field
    end

    def convert_field(field, type, count)
      it = "#{type}"
      it << "#{@input_big ? ">" : "<"}" if DATA_SIZES[type] > 1
      #ot = "#{type}#{@output_big ? ">" : "<"}"
      vs = count.times.collect {
        s = @input.read(DATA_SIZES[type])
        v = s.unpack(it).first
        s.reverse! if @input_big != @output_big
        @output.write(s)
        v
      }
      vs = vs.first if count == 1
      send("#{field}=", vs)
    end

    def convert_fields
      self.class.instance_variable_get(:@fields).each { |field, type, count|
        convert_field(field, type, count)
      }
    end

    def convert(input, output, input_big, output_big)
      set_convert_type(input, output, input_big, output_big)
      convert_fields
    end

    def self.convert(input, output, input_big, output_big)
      h = self::new
      h.convert(input, output, input_big, output_big)
      h
    end

  end

end
