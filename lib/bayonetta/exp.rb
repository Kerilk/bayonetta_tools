module Bayonetta

  class EXPFile2 < LibBin::DataConverter

    class EXPFileHeader < LibBin::DataConverter
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

    class Record < LibBin::DataConverter
      int16 :bone_index
      int8 :animation_track
      int8 :padding
      int16 :num_operations
      int16 :unknown
      uint32 :offset

      def initialize
        @bone_index = 0
        @animation_track = 0
        @padding = 0
        @num_operations = 0
        @unknown = 0
        @offset = 0
      end

    end

    class Operation < LibBin::DataConverter
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

    class Entry < LibBin::DataConverter
      register_field :operations, Operation, count: '..\records[__index]\num_operations'

      def initialize
        @operations = []
      end

      def abs(v)
        v.abs
      end

      def get_value(tracks, table, interpolation_entries)
        s = ""
        @operations.each { |o|
          case o.type
          when 0
            nil
          when 1
            s << "("
          when 2
            s << ")"
          when 3
            s << "tracks[table[#{o.number}]][#{o.info}]"
          when 4
            s << "#{o.value}"
          when 5
            case o.number
            when 0
              s << " + "
            when 2
              s << " * "
            else
              raise "Unknown arithmetic operation: #{o.number}!"
            end
          when 6
            raise "Unknown function argument number: #{o.info}!" if o.info != 1
            case o.number
            when 1
              s << "abs("
            else
              raise "Unknown function: #{o.number}!"
            end
          when 7
            s << ")"
          when 8
            s << "interpolation_entries[#{o.number}].get_value("
          else
            raise "Unknown operation: #{o.type}!"
          end
        }
        eval s
      end

    end

    class Interpolation < LibBin::DataConverter
      int16 :num_points
      int16 :padding
      uint32 :offset

      def initialize
        @num_points = 0
        @padding = 0
        @offset = 0
      end

    end

    class Point < LibBin::DataConverter
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

    class InterpolationEntry < LibBin::DataConverter
      register_field :points, Point, count: '..\interpolations[__index]\num_points'

      def get_value(val)
        @points.each_cons(2) { |left, right|
          if left.v <= val && right.v >= val
            p0 = left.p
            p1 = right.p
            m0 = left.m1
            m1 = right.m0
            t = (val - left.v).to_f / (right.v - left.v)
            return (2 * t*t*t - 3 * t*t + 1)*p0 + (t*t*t - 2 * t*t + t)*m0 + (-2 * t*t*t + 3 * t*t)*p1 + (t*t*t - t * t)*m1
          end

        }
        return 0.0
      end

    end

    register_field :header, EXPFileHeader
    register_field :records, Record, count: 'header\num_records', offset: 'header\offset_records'
    register_field :entries, Entry, count: 'header\num_records', sequence: true,
      offset: 'records[__iterator]\offset + header\offset_records + 12*__iterator'
    register_field :interpolations, Interpolation, count: 'header\num_interpolations', offset: 'header\offset_interpolations'
    register_field :interpolation_entries, InterpolationEntry, count: 'header\num_interpolations', sequence: true,
      offset: 'interpolations[__iterator]\offset + header\offset_interpolations + 8*__iterator'

    def apply(tracks, table)
      rad_to_deg = 180.0 / Math::PI
      deg_to_rad = Math::PI / 180.0
      tracks.each { |tr|
        tr[0] *= 10.0
        tr[1] *= 10.0
        tr[2] *= 10.0
        tr[3] *= rad_to_deg
        tr[4] *= rad_to_deg
        tr[5] *= rad_to_deg
      }
      @records.each_with_index { |r, i|
        bone_index = table[r.bone_index]
        next unless bone_index
        animation_track = r.animation_track
        if @entries[i]
          value = @entries[i].get_value(tracks, table, interpolation_entries)
        end
        tracks[bone_index][animation_track] = value
      }
      tracks.each { |tr|
        tr[0] *= 0.1
        tr[1] *= 0.1
        tr[2] *= 0.1
        tr[3] *= deg_to_rad
        tr[4] *= deg_to_rad
        tr[5] *= deg_to_rad
      }
    end

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

  class EXPFile < LibBin::DataConverter

    class EXPFileHeader < LibBin::DataConverter
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

    class Record < LibBin::DataConverter
      int16 :u_a
      int16 :bone_index
      int8 :animation_track
      int8 :entry_type
      int8 :u_b
      int8 :interpolation_type
      int16 :num_points
      int16 :u_c
      uint32 :offset
      uint32 :offset_interpolation

      def initialize
        @u_a = 0
        @bone_index = 0
        @animation_track = 0
        @entry_type = 0
        @u_b = 0
        @interpolation_type = 0
        @num_points = 0
        @offset = 0
        @offset_interpolation = 0
      end

    end

    class Operation < LibBin::DataConverter
      uint32 :flags
      float :value

      def initialize
        @flags = 0
        @value = 0.0
      end

      def transform_value( v )
        if @flags == 0x4
          v *= @value
        elsif @flags == 0x20004
          v = v.abs * @value
        elsif @flags == 0x1
          v += @value
        else
          raise "Unknown operation #{ "%x" % @flags }, please report!"
        end
        v
      end

    end

    class Entry1 < LibBin::DataConverter
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

      def get_value(pose, table)
        pose[table[@bone_index]][@animation_track]
      end

    end

    class Entry2 < LibBin::DataConverter
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

      def get_value(pose, table)
        @operation.transform_value( pose[table[@bone_index]][@animation_track] )
      end

    end

    class Entry3 < LibBin::DataConverter
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

      def get_value(pose, table)
        v = @operations[0].transform_value( pose[table[@bone_index]][@animation_track] )
        v = @operations[1].transform_value( v )
      end

    end

    class Entry < LibBin::DataConverter

      def self.convert(input, output, input_big, output_big, parent, index)
        entry_type = parent.records[index].entry_type
        entry = nil
        case entry_type
        when 1
          entry = Entry1::convert(input, output, input_big, output_big, parent, index)
        when 2
          entry = Entry2::convert(input, output, input_big, output_big, parent, index)
        when 3
          entry = Entry3::convert(input, output, input_big, output_big, parent, index)
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

    class Point4 < LibBin::DataConverter
      float :v
      uint16 :dummy
      uint16 :cp
      uint16 :cm0
      uint16 :cm1

      def initialize
        @v = 0.0
        @dummy = 0
        @cp = 0
        @cm0 = 0
        @cm1 = 0
      end

      def size
        3 * 4
      end

    end

    class Interpolation4 < LibBin::DataConverter
      float :p
      float :dp
      float :m0
      float :dm0
      float :m1
      float :dm1
      register_field :points, Point4, count: '..\records[__index]\num_points'

      def size
        4 * 6 + @points.collect(&:size).reduce(:+)
      end

      def interpolate(val)
        @points.each_cons(2) { |left, right|
          if left.v <= val && right.v >= val
            p0 = @p + left.cp * @dp
            p1 = @p + right.cp * @dp
            m0 = @m1 + left.cm1 * @dm1
            m1 = @m0 + right.cm0 * @dm0
            t = (val - left.v).to_f / (right.v - left.v)
            return (2 * t*t*t - 3 * t*t + 1)*p0 + (t*t*t - 2 * t*t + t)*m0 + (-2 * t*t*t + 3 * t*t)*p1 + (t*t*t - t * t)*m1
          end

        }
        return 0.0
      end
    end

    class Interpolation < LibBin::DataConverter

      def self.convert(input, output, input_big, output_big, parent, index)
        interpolation_type = parent.records[index].interpolation_type
        interpolation = nil
        case interpolation_type
        when 4
          interpolation = Interpolation4::convert(input, output, input_big, output_big, parent, index)
        when -1
          interpolation = nil
        else
          raise "Unknown Interpolation type: #{interpolation_type}, please report!"
        end
        interpolation
      end

      def self.load(input, input_big, parent, index)
        interpolation_type = parent.records[index].interpolation_type
        interpolation = nil
        case interpolation_type
        when 4
          interpolation = Interpolation4::load(input, input_big, parent, index)
        when -1
          interpolation = nil
        else
          raise "Unknown Interpolation type: #{interpolation_type}, please report!"
        end
        interpolation
      end

    end

    register_field :header, EXPFileHeader
    register_field :records, Record, count: 'header\num_records', offset: 'header\offset_records'
    register_field :entries, Entry, count: 'header\num_records', sequence: true,
      offset: 'records[__iterator]\offset'
    register_field :interpolations, Interpolation, count: 'header\num_records', sequence: true,
      offset: 'records[__iterator]\offset_interpolation'

    def was_big?
      @__was_big
    end

    def apply(tracks, table)
      rad_to_deg = 180.0 / Math::PI
      deg_to_rad = Math::PI / 180.0
      tracks.each { |tr|
        tr[0] *= 10.0
        tr[1] *= 10.0
        tr[2] *= 10.0
        tr[3] *= rad_to_deg
        tr[4] *= rad_to_deg
        tr[5] *= rad_to_deg
      }
      @records.each_with_index { |r, i|
        bone_index = table[r.bone_index]
        next unless bone_index
        animation_track = r.animation_track
        if @entries[i]
          value = @entries[i].get_value(tracks, table)
        end
        if @interpolations[i]
          value = @interpolations[i].interpolate(value)
        end
        tracks[bone_index][animation_track] = value
      }
      tracks.each { |tr|
        tr[0] *= 0.1
        tr[1] *= 0.1
        tr[2] *= 0.1
        tr[3] *= deg_to_rad
        tr[4] *= deg_to_rad
        tr[5] *= deg_to_rad
      }
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

      table = @records.zip(@entries).to_h
      reverse_table = table.invert
      interpolation_table = @records.zip(@interpolations).to_h
      reverse_interpolation_table = interpolation_table.invert

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
      @interpolations.each { |i|
        if i
          reverse_interpolation_table[i].offset_interpolation = last_offset
          last_offset += i.size
        end
      }

      @entries = @records.collect { |r| table[r] }
      @interpolation = @records.collect { |r| interpolation_table[r] }
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
