module Bayonetta

  class DataConverter

    def inspect
      to_s
    end

    DATA_SIZES = {
      :c => 1,
      :C => 1,
      :s => 2,
      :S => 2,
      :l => 4,
      :L => 4
    }
    attr_reader :__parent
    attr_reader :__index
    attr_reader :__iterator
    attr_reader :__position
    def set_convert_type(input, output, input_big, output_big, parent, index)
      @input_big = input_big
      @output_big = output_big
      @input = input
      @output = output
      @__parent = parent
      @__index = index
      @__position = input.tell
    end

    def set_load_type(input, input_big, parent, index)
      @input_big = input_big
      @input = input
      @__parent = parent
      @__index = index
      @__position = input.tell
    end

    def set_dump_type(output, output_big, parent, index)
      @output_big = output_big
      @output = output
      @__parent = parent
      @__index = index
      @__position = output.tell
    end

    def unset_convert_type
      @input_big = nil
      @output_big = nil
      @input = nil
      @output = nil
      @__parent = nil
      @__index = nil
      @__position = nil
    end

    def unset_load_type
      @input_big = nil
      @input = nil
      @__parent = nil
      @__index = nil
      @__position = nil
    end

    def unset_dump_type
      @output_big = nil
      @output = nil
      @__parent = nil
      @__index = nil
      @__position = nil
    end

    def self.inherited(subclass)
      subclass.instance_variable_set(:@fields, [])
    end

    def self.register_field(field, type, count: nil, offset: nil, sequence: false, condition: nil)
      @fields.push([field, type, count, offset, sequence, condition])
      attr_accessor field
    end

    def decode_symbol(sym)
      exp = sym.gsub("..","__parent").gsub("\\",".")
      p exp
      res = eval(exp)
      p res
      res
 #     path = sym.split("/")
 #     path.reduce(nil) { |s, e|
 #       e = "__parent" if e == ".."
 #       s ? s.send(e) : send(e)
 #     }
    end

    def decode_seek_offset(offset)
      if offset
        offset = decode_symbol(offset)
        return false if offset == 0x0
        @input.seek(offset) if @input
        @output.seek(offset) if @output
        return offset
      end
    end

    def decode_condition(condition)
      return true unless condition
      return decode_symbol(condition)
    end

    def decode_count(count)
      if count
        if count.kind_of?(String)
          c = decode_symbol(count)
        else
          c = count
        end
      else
        c = 1
      end
      c
    end

    def convert_data_field(field, type, count, offset, sequence, condition)
      unless sequence
        off = decode_seek_offset(offset)
        return nil if off == false
        cond = decode_condition(condition)
        return nil unless cond
      end
      c = decode_count(count)
      vs = c.times.collect { |it|
        @__iterator = it
        if sequence
          off = decode_seek_offset(offset)
          cond = decode_condition(condition)
          if off == false || !cond
            nil
          else
            type::convert(@input, @output, @input_big, @output_big, self, it)
          end
        else
          type::convert(@input, @output, @input_big, @output_big, self, it)
        end
      }
      @__iterator = nil
      vs = vs.first unless count
      vs
    end

    def load_data_field(field, type, count, offset, sequence, condition)
      unless sequence
        off = decode_seek_offset(offset)
        return nil if off == false
        cond = decode_condition(condition)
        return nil unless cond
      end
      c = decode_count(count)
      vs = c.times.collect { |it|
        @__iterator = it
        if sequence
          off = decode_seek_offset(offset)
          cond = decode_condition(condition)
          if off == false || !cond
            nil
          else
            type::load(@input, @input_big, self, it)
          end
        else
          type::load(@input, @input_big, self, it)
        end
      }
      @__iterator = nil
      vs = vs.first unless count
      vs
    end

    def dump_data_field(vs, field, type, count, offset, sequence, condition)
      unless sequence
        off = decode_seek_offset(offset)
        return nil if off == false
        cond = decode_condition(condition)
        return nil unless cond
      end
      c = decode_count(count)
      vs = [vs] unless count
      vs.each_with_index { |v, it|
        @__iterator = it
        if sequence
          off = decode_seek_offset(offset)
          cond = decode_condition(condition)
          if off == false || !cond
            nil
          else
            v.dump(@output, @output_big, self, it)
          end
        else
          v.dump(@output, @output_big, self, it)
        end
      }
      @__iterator = nil
    end

    def convert_sacalar_field(field, type, count, offset, sequence, condition)
      unless sequence
        off = decode_seek_offset(offset)
        return nil if off == false
        cond = decode_condition(condition)
        return nil unless cond
      end

      c = decode_count(count)
      t = "#{type}"
      t << "#{@input_big ? ">" : "<"}" if DATA_SIZES[type] > 1
      vs = c.times.collect { |it|
        @__iterator = it
        if sequence
          off = decode_seek_offset(offset)
          cond = decode_condition(condition)
          if off == false || !cond
            nil
          else
            s = @input.read(DATA_SIZES[type])
            v = s.unpack(t).first
            s.reverse! if @input_big != @output_big
            @output.write(s)
            v
          end
        else
          s = @input.read(DATA_SIZES[type])
          v = s.unpack(t).first
          s.reverse! if @input_big != @output_big
          @output.write(s)
          v
        end
      }
      @__iterator = nil
      vs = vs.first unless count
      vs
    end

    def load_sacalar_field(field, type, count, offset, sequence, condition)
      unless sequence
        off = decode_seek_offset(offset)
        return nil if off == false
        cond = decode_condition(condition)
        return nil unless cond
      end

      c = decode_count(count)
      t = "#{type}"
      t << "#{@input_big ? ">" : "<"}" if DATA_SIZES[type] > 1
      vs = c.times.collect { |it|
        @__iterator = it
        if sequence
          off = decode_seek_offset(offset)
          cond = decode_condition(condition)
          if off == false || !cond
            nil
          else
            s = @input.read(DATA_SIZES[type])
            s.unpack(t).first
          end
        else
          s = @input.read(DATA_SIZES[type])
          s.unpack(t).first
        end
      }
      @__iterator = nil
      vs = vs.first unless count
      vs
    end

    def dump_sacalar_field(vs, field, type, count, offset, sequence, condition)
      unless sequence
        off = decode_seek_offset(offset)
        return nil if off == false
        cond = decode_condition(condition)
        return nil unless cond
      end

      c = decode_count(count)
      t = "#{type}"
      t << "#{@output_big ? ">" : "<"}" if DATA_SIZES[type] > 1
      vs = [vs] unless count
      vs.each_with_index { |v, it|
        @__iterator = it
        if sequence
          off = decode_seek_offset(offset)
          cond = decode_condition(condition)
          if off == false || !cond
            nil
          else
            @output.write([v].pack(t))
          end
        else
          @output.write([v].pack(t))
        end
      }
      @__iterator = nil
    end

    def convert_field(*args)
      field = args[0]
      type = args[1]
      if type.kind_of?(Class) && type < DataConverter
        vs = convert_data_field(*args)
      elsif type.kind_of?(Symbol)
        vs = convert_sacalar_field(*args)
      else
        raise "Unsupported type: #{type.inspect}!"
      end
      send("#{field}=", vs)
    end

    def load_field(*args)
      field = args[0]
      type = args[1]
      if type.kind_of?(Class) && type < DataConverter
        vs = load_data_field(*args)
      elsif type.kind_of?(Symbol)
        vs = load_sacalar_field(*args)
      else
        raise "Unsupported type: #{type.inspect}!"
      end
      send("#{field}=", vs)
    end

    def dump_field(*args)
      field = args[0]
      type = args[1]
      vs = send("#{field}")
      if type.kind_of?(Class) && type < DataConverter
        s = dump_data_field(vs, *args)
      elsif type.kind_of?(Symbol)
        s = dump_sacalar_field(vs, *args)
      else
        raise "Unsupported type: #{type.inspect}!"
      end
    end

    def convert_fields
      self.class.instance_variable_get(:@fields).each { |args|
        convert_field(*args)
      }
      self
    end

    def load_fields
      self.class.instance_variable_get(:@fields).each { |args|
        load_field(*args)
      }
      self
    end

    def dump_fields
      self.class.instance_variable_get(:@fields).each { |args|
        dump_field(*args)
      }
      self
    end

    def convert(input, output, input_big, output_big, parent = nil, index = nil)
      set_convert_type(input, output, input_big, output_big, parent, index)
      convert_fields
      unset_convert_type
      self
    end

    def load(input, input_big, parent = nil, index = nil)
      set_load_type(input, input_big, parent, index)
      load_fields
      unset_load_type
      self
    end

    def dump(output, output_big, parent = nil, index = nil)
      set_dump_type(output, output_big, parent, index)
      dump_fields
      unset_dump_type
      self
    end
      
    def self.convert(input, output, input_big, output_big, parent = nil, index = nil)
      h = self::new
      h.convert(input, output, input_big, output_big, parent, index)
      h
    end

    def self.load(input, input_big, parent = nil, index = nil)
      h = self::new
      h.load(input, input_big, parent, index)
      h
    end

  end

end
