module Bayonetta

  class PGHalf < DataConverter
    uint16 :data

    def value
      Flt::IEEE_binary16_pg::from_bytes([@data].pack("S")).to(Float)
    end

    def value=(v)
      s = Flt::IEEE_binary16_pg::new(v).to_bytes
      @data = s.unpack("s").first
      v
    end

  end

  class MOT2File < DataConverter

    class Interpolation1 < DataConverter
      float :keys, count: '..\records[__index]\num_keys'

      def values(frame_count)
        count = frame_count
        @keys + [@keys.last] * (count - keys.length)
      end

      def value(frame_index)
        v = @keys[frame_index]
        v = @keys.last unless v
        v
      end

    end

    class Interpolation2 < DataConverter
      float :p
      float :dp
      uint16 :keys, count: '..\records[__index]\num_keys'

      def values(frame_count)
        count = frame_count
        res = @keys.collect { |k| @p + k*@cp }
        res + [res.last] * (frame_count - keys.length)
      end

      def value(frame_index)
        cp = @keys[frame_index]
        cp = @keys.last unless cp
        @p + cp*@dp
      end

    end

    class Interpolation3 < DataConverter
      pghalf :p
      pghalf :dp
      uint16 :keys, count: '..\records[__index]\num_keys'

      def values(frame_count)
        count = frame_count
        res = @keys.collect { |k| @p + k*@cp }
        res + [res.last] * (frame_count - keys.length)
      end

      def value(frame_index)
        cp = @keys[frame_index]
        cp = @keys.last unless cp
        @p + cp*@dp
      end

    end

  end

  class MOTFile < DataConverter

    class Interpolation1 < DataConverter
      float :keys, count: '..\records[__index]\num_keys'

      def values(frame_count)
        count = frame_count
        @keys + [@keys.last] * (count - keys.length)
      end

      def value(frame_index)
        v = @keys[frame_index]
        v = @keys.last unless v
        v
      end

    end

    class Key4 < DataConverter
      uint16 :index
      uint16 :cp
      uint16 :cm0
      uint16 :cm1

      def initialize
        @index = 0
        @cp = 0
        @cm0 = 0
        @cm1 = 0
      end

      def size
        2 * 4
      end

    end

    class Interpolation4 < DataConverter
      float :p
      float :dp
      float :m0
      float :dm0
      float :m1
      float :dm1
      register_field :keys, Key4, count: '..\records[__index]\num_keys'

      def size
        4 * 6 + @points.collect(&:size).reduce(:+)
      end

      def values(frame_count)
        count = frame_count
        vs = [0.0]*count
        (@keys.length - 1).times { |i|
          (@keys[i+1].index..@keys[i].index).each { |frame|
            p_0 = @p + @keys[i].cp * @dp
            p_1 = @p + @keys[i+1].cp * @dp
            m_0 = @m1 + @keys[i].cm1 * @dm1
            m_1 = @m0 + @keys[i+1].cm0 * @dm0
            t = (frame - @keys[i].index).to_f / (@keys[i+1].index - @keys[i].index)
            vs[frame] = (2 * t*t*t - 3 * t*t + 1)*p_0 + (t*t*t - 2 * t*t + t)*m_0 + (-2 * t*t*t + 3 * t*t)*p_1 + (t*t*t - t * t)*m_1
          }
        }
        (0...@keys.first.index).each { |i|
          vs[i] = vs[@keys.first.index]
        }
        ((@keys.last.index+1)..(count-1)).each { |i|
          vs[i] = vs[@keys.last.index]
        }
        vs
      end

      def value(frame_index)
        if frame_index <= @keys.first.index
          return @p + @keys.first.cp * @dp
        elsif frame_index >= @keys.last.index
          return @p + @keys.last.cp * @dp
        else
          (@keys.length - 1).times { |i|
            if frame_index <= @keys[i+1].index && frame_index >= @keys[i].index
              p_0 = @p + @keys[i].cp * @dp
              p_1 = @p + @keys[i+1].cp * @dp
              m_0 = @m1 + @keys[i].cm1 * @dm1
              m_1 = @m0 + @keys[i+1].cm0 * @dm0
              t = (frame_index - @keys[i].index).to_f / (@keys[i+1].index - @keys[i].index)
              return (2 * t*t*t - 3 * t*t + 1)*p_0 + (t*t*t - 2 * t*t + t)*m_0 + (-2 * t*t*t + 3 * t*t)*p_1 + (t*t*t - t * t)*m_1
            end
          }
        end
      end

    end

    class Key6 < DataConverter
      uint8 :index
      uint8 :cp
      uint8 :cm0
      uint8 :cm1

      def initialize
        @index = 0
        @cp = 0
        @cm0 = 0
        @cm1 = 0
      end

      def size
        1 * 4
      end

    end

    class Interpolation6 < DataConverter
      pghalf :p
      pghalf :dp
      pghalf :m0
      pghalf :dm0
      pghalf :m1
      pghalf :dm1
      register_field :keys, Key6, count: '..\records[__index]\num_keys'

      def size
        2 * 6 + @points.collect(&:size).reduce(:+)
      end

      def values(frame_count)
        count = frame_count
        vs = [0.0]*count
        index1 = @keys.first.index
        (@keys.length - 1).times { |i|
          index2 = @keys[i+1].index + index1
          (index1..index2).each { |frame|
            p_0 = @p + @keys[i].cp * @dp
            p_1 = @p + @keys[i+1].cp * @dp
            m_0 = @m1 + @keys[i].cm1 * @dm1
            m_1 = @m0 + @keys[i+1].cm0 * @dm0
            t = (frame - index1).to_f / (index2 - index1)
            vs[frame] = (2 * t*t*t - 3 * t*t + 1)*p_0 + (t*t*t - 2 * t*t + t)*m_0 + (-2 * t*t*t + 3 * t*t)*p_1 + (t*t*t - t * t)*m_1
          }
          index1 = index2
        }
        (0...@keys.first.index).each { |i|
          vs[i] = vs[@keys.first.index]
        }
        ((index1+1)..(count-1)).each { |i|
          vs[i] = vs[index1]
        }
        vs
      end

      def value(frame_index)

        if frame_index <= @keys.first.index
          return @p + @keys.first.cp * @dp
        end
        index1 = @keys.first.index
        (@keys.length - 1).times { |i|
          index2 = @keys[i+1].index + index1
          if frame_index <= index2 && frame_index >= index1
            p_0 = @p + @keys[i].cp * @dp
            p_1 = @p + @keys[i+1].cp * @dp
            m_0 = @m1 + @keys[i].cm1 * @dm1
            m_1 = @m0 + @keys[i+1].cm0 * @dm0
            t = (frame_index - index1).to_f / (index2 - index1)
            return (2 * t*t*t - 3 * t*t + 1)*p_0 + (t*t*t - 2 * t*t + t)*m_0 + (-2 * t*t*t + 3 * t*t)*p_1 + (t*t*t - t * t)*m_1
          end
          index1 = index2
        }
        if frame_index >= index1
          return @p + @keys.last.cp * @dp
        end
        raise "Error, please report!"
      end

    end

    class Key7 < DataConverter
      uint16 :index
      uint8 :dummy
      uint8 :cp
      uint8 :cm0
      uint8 :cm1

      def initialize
        @index = 0
        @dummy = 0
        @cp = 0
        @cm0 = 0
        @cm1 = 0
      end

      def size
        1 * 4 + 2
      end

    end

    class Interpolation7 < DataConverter
      pghalf :p
      pghalf :dp
      pghalf :m0
      pghalf :dm0
      pghalf :m1
      pghalf :dm1
      register_field :keys, Key7, count: '..\records[__index]\num_keys'

      def size
        2 * 6 + @points.collect(&:size).reduce(:+)
      end

      def values(frame_count)
        count = frame_count
        vs = [0.0]*count
        (@keys.length - 1).times { |i|
          (@keys[i+1].index..@keys[i].index).each { |frame|
            p_0 = @p + @keys[i].cp * @dp
            p_1 = @p + @keys[i+1].cp * @dp
            m_0 = @m1 + @keys[i].cm1 * @dm1
            m_1 = @m0 + @keys[i+1].cm0 * @dm0
            t = (frame - @keys[i].index).to_f / (@keys[i+1].index - @keys[i].index)
            vs[frame] = (2 * t*t*t - 3 * t*t + 1)*p_0 + (t*t*t - 2 * t*t + t)*m_0 + (-2 * t*t*t + 3 * t*t)*p_1 + (t*t*t - t * t)*m_1
          }
        }
        (0...@keys.first.index).each { |i|
          vs[i] = vs[@keys.first.index]
        }
        ((@keys.last.index+1)..(count-1)).each { |i|
          vs[i] = vs[@keys.last.index]
        }
        vs
      end

      def value(frame_index)
        if frame_index <= @keys.first.index
          return @p + @keys.first.cp * @dp
        elsif frame_index >= @keys.last.index
          return @p + @keys.last.cp * @dp
        else
          (@keys.length - 1).times { |i|
            if frame_index <= @keys[i+1].index && frame_index >= @keys[i].index
              p_0 = @p + @keys[i].cp * @dp
              p_1 = @p + @keys[i+1].cp * @dp
              m_0 = @m1 + @keys[i].cm1 * @dm1
              m_1 = @m0 + @keys[i+1].cm0 * @dm0
              t = (frame_index - @keys[i].index).to_f / (@keys[i+1].index - @keys[i].index)
              return (2 * t*t*t - 3 * t*t + 1)*p_0 + (t*t*t - 2 * t*t + t)*m_0 + (-2 * t*t*t + 3 * t*t)*p_1 + (t*t*t - t * t)*m_1
            end
          }
        end
      end

    end

    class Interpolation < DataConverter

      def self.convert(input, output, input_big, output_big, parent, index)
        interpolation_type = parent.records[index].interpolation_type
        interpolation = nil
        case interpolation_type
        when 1
          interpolation = Interpolation1::convert(input, output, input_big, output_big, parent, index)
        when 4
          interpolation = Interpolation4::convert(input, output, input_big, output_big, parent, index)
        when 6
          interpolation = Interpolation6::convert(input, output, input_big, output_big, parent, index)
        when 7
          interpolation = Interpolation7::convert(input, output, input_big, output_big, parent, index)
        when -1, 0
          interpolation = nil
        else
          raise "Unknown interpolation type: #{interpolation_type}, please report!"
        end
        interpolation
      end

      def self.load(input, input_big, parent, index)
        interpolation_type = parent.records[index].interpolation_type
        interpolation = nil
        case interpolation_type
        when 1
          interpolation = Interpolation1::load(input, input_big, parent, index)
        when 4
          interpolation = Interpolation4::load(input, input_big, parent, index)
        when 6
          interpolation = Interpolation6::load(input, input_big, parent, index)
        when 7
          interpolation = Interpolation7::load(input, input_big, parent, index)
        when -1, 0
          interpolation = nil
        else
          raise "Unknown interpolation type: #{interpolation_type}, please report!"
        end
      end

    end

    class Record < DataConverter
      int16 :bone_index
      int8 :animation_track
      int8 :interpolation_type
      int16 :num_keys
      int16 :u_a
      uint32 :offset

      def value
        raise "Only animation track 1 have a value" unless @interpolation_type == 0 
        [@offset].pack("L").unpack("F").first
      end

      def size
        2 + 1*2 + 2*2 + 4
      end
    end

    class Header < DataConverter
      int8 :id, count: 4
      uint16 :flag
      uint16 :frame_count
      uint32 :offset_records
      uint32 :num_records
    end

    register_field :header, Header
    register_field :records, Record, count: 'header\num_records', offset: 'header\offset_records'
    register_field :interpolations, Interpolation, count: 'header\num_records', sequence: true, offset: 'records[__iterator]\offset', condition: 'records[__iterator]\interpolation_type != 0'

    def decode_frame(frame_index)
      raise "Invalid frame number #{frame_index} (#{0} - #{@header.frame_count}!" if frame_index < 0 || frame_index >= @header.frame_count
      tracks = Hash::new { |h,k| h[k] = {} }
      @records.each_with_index { |r, i|
        if r.interpolation_type != -1
          if r.interpolation_type == 0
            tracks[r.bone_index][r.animation_track] = r.value
          else
            tracks[r.bone_index][r.animation_track] = @interpolations[i].value(frame_index)
          end
        end
      }
      tracks
    end

    def decode
      tracks = Hash::new { |h,k| h[k] = {} }
      motion = {}
      motion[:flag] = @header.flag
      motion[:frame_count] = frame_count = @header.frame_count
      motion[:tracks] = tracks
      @records.each_with_index { |r, i|
        if r.interpolation_type != -1
          if r.interpolation_type == 0
            tracks[r.bone_index][r.animation_track] = [r.value] * frame_count
          else
            tracks[r.bone_index][r.animation_track] = @interpolations[i].values(frame_count)
          end
        end
      }
      motion
    end

    def self.is_bayo2?(f)
      f.rewind
      id = f.read(4)
      raise "Invalid id #{id.inspect}!" if id != "mot\0".b
      uint = "L<"
      version_big = f.read(4).unpack(uint).first
      f.rewind
      return true if version_big == 0x20120405
      uint = "L>"
      version_small = f.read(4).unpack(uint).first
      f.rewind
      return true if version_small == 0x20120405
      return false
    end

    def self.is_big?(f)
      f.rewind
      block = lambda { |int|
        id = f.read(4)
        raise "Invalid id #{id.inspect}!" if id != "mot\0".b
        f.read(4)
        offset_records = f.read(4).unpack(int).first
        num_records = f.read(4).unpack(int).first
        num_records >= 0 && num_records*12 < f.size && offset_records > 0 && offset_records < f.size
      }
      big = block.call("l>")
      f.rewind
      small = block.call("l<")
      f.rewind
      raise "Invalid data!" unless big ^ small
      return big
    end

    def self.convert(input_name, output_name, input_big = true, output_big = false)
      input = File.open(input_name, "rb")
      id = input.read(4).unpack("a4").first
      raise "Invalid file type #{id}!" unless id == "mot\0".b
      output = File.open(output_name, "wb")
      output.write("\x00"*input.size)
      input.seek(0);
      output.seek(0);

      if is_bayo2?(input)
        raise "Bayo 2 motions unsuported for now!"
      else
        mot = self::new
      end
      mot.convert(input, output, input_big, output_big)

      input.close
      output.close
    end

    def self.load(input_name)
      if input_name.respond_to?(:read) && input_name.respond_to?(:seek)
        input = input_name
      else
        input = File.open(input_name, "rb")
      end

      if is_bayo2?(input)
        raise "Bayo 2 motions unsuported for now!"
      end

      input_big = is_big?(input)

      mot = self::new
      mot.instance_variable_set(:@__was_big, input_big)
      mot.load(input, input_big)
      input.close unless input_name.respond_to?(:read) && input_name.respond_to?(:seek)

      mot
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
