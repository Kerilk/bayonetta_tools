module Bayonetta

  module MOTRemaper

    def remap_bones(map)
      @records.each { |r|
        if map[r.bone_index]
          r.bone_index = map[r.bone_index]
        end
      }
    end

  end

  module MOTDecoder

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

  end

  module QuantizedValues
    def get_p(i)
      @p + @keys[i].cp * @dp
    end

    def get_m1(i)
      @m1 + @keys[i].cm1 * @dm1
    end

    def get_m0(i)
      @m0 + @keys[i].cm0 * @dm0
    end
  end

  module DirectValues
    def get_p(i)
      @keys[i].p
    end

    def get_m1(i)
      @keys[i].m1
    end

    def get_m0(i)
      @keys[i].m0
    end
  end

  module AbsoluteIndexes
    def key_frame_indexes
      @keys.collect { |k| k.index }
    end
  end

  module RelativeIndexes
    def key_frame_indexes
      res = []
      index = 0
      (@keys.length).times { |i|
        index = @keys[i].index + index
        res.push index
      }
      res
    end
  end

  module KeyFrameInterpolate
    def interpol(frame, start_index, stop_index, i)
      p_0 = get_p(i)
      p_1 = get_p(i+1)
      m_0 = get_m1(i)
      m_1 = get_m0(i+1)
      t = (frame - start_index).to_f / (stop_index - start_index)
      (2 * t*t*t - 3 * t*t + 1)*p_0 + (t*t*t - 2 * t*t + t)*m_0 + (-2 * t*t*t + 3 * t*t)*p_1 + (t*t*t - t * t)*m_1
    end

    def values(frame_count)
      vs = [0.0]*frame_count
      kfis = key_frame_indexes
      kfis.each_cons(2).each_with_index { |(start_index, stop_index), i|
        (start_index..stop_index).each { |frame|
          vs[frame] = interpol(frame, start_index, stop_index, i)
        }
      }
      (0...kfis.first).each { |i|
        vs[i] = vs[kfis.first]
      }
      ((kfis.last+1)...frame_count).each { |i|
        vs[i] = vs[kfis.last]
      }
      vs
    end

    def value(frame_index)
      kfis = key_frame_indexes
      if frame_index <= kfis.first
        return get_p(0)
      elsif frame_index >= kfis.last
        return get_p(kfis.length - 1)
      else
        kfis.each_cons(2).each_with_index { |(start_index, stop_index), i|
          if frame_index <= stop_index && frame_index >= start_index
            return interpol(frame_index, start_index, stop_index, i)
          end
        }
      end
    end

  end

  class MOT2File < LibBin::DataConverter
    include MOTDecoder
    include MOTRemaper

    class Interpolation1 < LibBin::DataConverter
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

    class Interpolation2 < LibBin::DataConverter
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

    class Interpolation3 < LibBin::DataConverter
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

    class Key4 < LibBin::DataConverter
      uint16 :index
      uint16 :dummy
      float :p
      float :m0
      float :m1

      def __size
        16
      end

    end

    class Interpolation4 < LibBin::DataConverter
      include DirectValues
      include AbsoluteIndexes
      include KeyFrameInterpolate
      register_field :keys, Key4, count: '..\records[__index]\num_keys'

      def __size
        @keys.length * 16
      end

    end

    class Key5 < LibBin::DataConverter
      uint16 :index
      uint16 :cp
      uint16 :cm0
      uint16 :cm1
    end

    class Interpolation5 < LibBin::DataConverter
      include QuantizedValues
      include AbsoluteIndexes
      include KeyFrameInterpolate
      float :p
      float :dp
      float :m0
      float :dm0
      float :m1
      float :dm1
      register_field :keys, Key5, count: '..\records[__index]\num_keys'

      def __size
        24 + @keys.length * 8
      end

    end

    class Key6 < LibBin::DataConverter
      uint8 :index
      uint8 :cp
      uint8 :cm0
      uint8 :cm1
    end

    class Interpolation6 < LibBin::DataConverter
      include QuantizedValues
      include AbsoluteIndexes
      include KeyFrameInterpolate
      pghalf :p
      pghalf :dp
      pghalf :m0
      pghalf :dm0
      pghalf :m1
      pghalf :dm1
      register_field :keys, Key6, count: '..\records[__index]\num_keys'

      def __size
        12 + @keys.length * 4
      end

    end

    class Key7 < LibBin::DataConverter
      uint8 :index
      uint8 :cp
      uint8 :cm0
      uint8 :cm1
    end

    class Interpolation7 < LibBin::DataConverter
      include QuantizedValues
      include RelativeIndexes
      include KeyFrameInterpolate
      pghalf :p
      pghalf :dp
      pghalf :m0
      pghalf :dm0
      pghalf :m1
      pghalf :dm1
      register_field :keys, Key7, count: '..\records[__index]\num_keys'

      def __size
        12 + @keys.length * 4
      end

    end

    class Key8 < LibBin::DataConverter
      uint8 :index_proxy, count: 2
      uint8 :cp
      uint8 :cm0
      uint8 :cm1
      def index
        @index_proxy.pack("C2").unpack("S>").first
      end

      def index=(v)
        @index_proxy = [v].pack("S>").unpack("C2")
        v
      end
    end

    class Interpolation8 < LibBin::DataConverter
      include QuantizedValues
      include AbsoluteIndexes
      include KeyFrameInterpolate
      pghalf :p
      pghalf :dp
      pghalf :m0
      pghalf :dm0
      pghalf :m1
      pghalf :dm1
      register_field :keys, Key8, count: '..\records[__index]\num_keys'

      def __size
        12 + @keys.length * 4
      end

    end

    class Record < LibBin::DataConverter
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

      def __size
        12
      end
    end

    class Header < LibBin::DataConverter
      string :id, 4
      uint32 :version
      uint16 :flag
      uint16 :frame_count
      uint32 :offset_records
      uint32 :num_records
      int8 :u_a, count: 4
      string :name, 16
    end

    register_field :header, Header
    register_field :records, Record, count: 'header\num_records', offset: 'header\offset_records'
    register_field :interpolations,
      'interpolation_type_selector(records[__iterator]\interpolation_type)',
      count: 'header\num_records', sequence: true,
      offset: 'records[__iterator]\offset + header\offset_records + 12*__iterator',
      condition: 'records[__iterator]\interpolation_type != 0 && records[__iterator]\interpolation_type != -1'

    def interpolation_type_selector(interpolation_type)
      interpolation = nil
      case interpolation_type
      when 1
        interpolation = Interpolation1
      when 2
        interpolation = Interpolation2
      when 3
        interpolation = Interpolation3
      when 4
        interpolation = Interpolation4
      when 5
        interpolation = Interpolation5
      when 6
        interpolation = Interpolation6
      when 7
        interpolation = Interpolation7
      when 8
        interpolation = Interpolation8
      when -1, 0
        interpolation = nil
      else
        raise "Unknown interpolation type: #{interpolation_type}, please report!"
      end
      interpolation
    end

    def self.is_bayo2?(f)
      f.rewind
      id = f.read(4)
      raise "Invalid id #{id.inspect}!" if id != "mot\0".b
      uint = "L"
      version = f.read(4).unpack(uint).first
      f.rewind
      return true if version == 0x20120405 || version == 0x05041220
      return false
    end

    def self.is_big?(f)
      f.rewind
      block = lambda { |int|
        id = f.read(4)
        raise "Invalid id #{id.inspect}!" if id != "mot\0".b
        f.read(4).unpack(int).first == 0x20120405
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

      unless is_bayo2?(input)
        mot = MOTFile::new
      else
        mot = self::new
      end
      mot.__convert(input, output, input_big, output_big)

      input.close
      output.close
    end

    def self.load(input_name)
      if input_name.respond_to?(:read) && input_name.respond_to?(:seek)
        input = input_name
      else
        input = File.open(input_name, "rb")
      end

      unless is_bayo2?(input)
        input.close unless input_name.respond_to?(:read) && input_name.respond_to?(:seek)
        return MOT2File::load(input_name)
      end

      input_big = is_big?(input)

      mot = self::new
      mot.instance_variable_set(:@__was_big, input_big)
      mot.__load(input, input_big)
      input.close unless input_name.respond_to?(:read) && input_name.respond_to?(:seek)

      mot
    end

    def __dump(output_name, output_big = false)
      if output_name.respond_to?(:write) && output_name.respond_to?(:seek)
        output = output_name
      else
        output = File.open(output_name, "wb")
      end
      output.rewind

      __set_dump_type(output, output_big, nil, nil)
      __dump_fields
      __unset_dump_type
      output.close unless output_name.respond_to?(:write) && output_name.respond_to?(:seek)
      self
    end

    def was_big?
      @__was_big
    end

  end

  class MOTFile < LibBin::DataConverter
    include MOTDecoder
    include MOTRemaper

    class Interpolation1 < LibBin::DataConverter
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

    class Key4 < LibBin::DataConverter
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

    end

    class Interpolation4 < LibBin::DataConverter
      include QuantizedValues
      include AbsoluteIndexes
      include KeyFrameInterpolate
      float :p
      float :dp
      float :m0
      float :dm0
      float :m1
      float :dm1
      register_field :keys, Key4, count: '..\records[__index]\num_keys'

      def __size
        24 + @keys.length*8
      end

    end

    class Key6 < LibBin::DataConverter
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

      def __size
        4
      end

    end

    class Interpolation6 < LibBin::DataConverter
      include QuantizedValues
      include RelativeIndexes
      include KeyFrameInterpolate
      pghalf :p
      pghalf :dp
      pghalf :m0
      pghalf :dm0
      pghalf :m1
      pghalf :dm1
      register_field :keys, Key6, count: '..\records[__index]\num_keys'

      def __size
        12 + @keys.length*4
      end

    end

    class Key7 < LibBin::DataConverter
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

      def __size
        6
      end

    end

    class Interpolation7 < LibBin::DataConverter
      include QuantizedValues
      include AbsoluteIndexes
      include KeyFrameInterpolate
      pghalf :p
      pghalf :dp
      pghalf :m0
      pghalf :dm0
      pghalf :m1
      pghalf :dm1
      register_field :keys, Key7, count: '..\records[__index]\num_keys'

      def __size
        12 + @keys.length * 6
      end

    end

    class Record < LibBin::DataConverter
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

      def __size
        12
      end
    end

    class Header < LibBin::DataConverter
      string :id, 4
      uint16 :flag
      uint16 :frame_count
      uint32 :offset_records
      uint32 :num_records
    end

    register_field :header, Header
    register_field :records, Record, count: 'header\num_records', offset: 'header\offset_records'
    register_field :interpolations,
      'interpolation_type_selector(records[__iterator]\interpolation_type)',
      count: 'header\num_records',
      sequence: true,
      offset: 'records[__iterator]\offset',
      condition: 'records[__iterator]\interpolation_type != 0'

    def interpolation_type_selector(interpolation_type)
      interpolation = nil
      case interpolation_type
      when 1
        interpolation = Interpolation1
      when 4
        interpolation = Interpolation4
      when 6
        interpolation = Interpolation6
      when 7
        interpolation = Interpolation7
      when -1, 0
        interpolation = nil
      else
        raise "Unknown interpolation type: #{interpolation_type}, please report!"
      end
    end

    def self.is_bayo2?(f)
      f.rewind
      id = f.read(4)
      raise "Invalid id #{id.inspect}!" if id != "mot\0".b
      uint = "L"
      version = f.read(4).unpack(uint).first
      f.rewind
      return true if version == 0x20120405 || version == 0x05041220
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
        mot = MOT2File::new
      else
        mot = self::new
      end
      mot.__convert(input, output, input_big, output_big)

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
        input.close unless input_name.respond_to?(:read) && input_name.respond_to?(:seek)
        return MOT2File::load(input_name)
      end

      input_big = is_big?(input)

      mot = self::new
      mot.instance_variable_set(:@__was_big, input_big)
      mot.__load(input, input_big)
      input.close unless input_name.respond_to?(:read) && input_name.respond_to?(:seek)

      mot
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

      __set_dump_type(output, output_big, nil, nil)
      __dump_fields
      __unset_dump_type
      output.close unless output_name.respond_to?(:write) && output_name.respond_to?(:seek)
      self
    end

  end

end
