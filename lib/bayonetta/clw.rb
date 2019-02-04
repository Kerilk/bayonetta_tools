module Bayonetta

  class CLWFile < LibBin::DataConverter

    class FVector < LibBin::DataConverter
      float :x
      float :y
      float :z

      def from_bxm_vector(v)
        @x, @y, @z = v.split(" ").collect(&:to_f)
        self
      end

      def self.from_bxm_vector(v)
        nv = self::new
        nv.from_bxm_vector(v)
        nv
      end

    end

    class ClothWind < LibBin::DataConverter
      int32 :wind_type
      int32 :parts_no
      register_field :offset,  FVector
      register_field :offset2, FVector
      float :radius
      float :power
      float :timer
      float :swing_rate
      float :swing_spd
      float :delay_max

      def from_bxm_cloth_wind(h)
        @wind_type = h.at_css("WindType").content.to_i
        @parts_no = h.at_css("PartsNo").content.to_i
        @offset = FVector.from_bxm_vector(h.at_css("Offset").content)
        @offset2 = FVector.from_bxm_vector(h.at_css("Offset2").content)
        @radius = h.at_css("Radius").content.to_f
        @power = h.at_css("Power").content.to_f
        @timer = h.at_css("Timer").content.to_f
        @swing_rate = h.at_css("SwingRate").content.to_f
        @swing_spd = h.at_css("SwingSpd").content.to_f
        @delay_max = h.at_css("DelayMax").content.to_f
        self
      end

      def self.from_bxm_cloth_wind(c)
        clw = self::new
        clw.from_bxm_cloth_wind(c)
        clw
      end

      def remap(map)
        @parts_no = check_and_remap_bone(map, @parts_no)
      end

      private
      def check_and_remap_bone(map, no)
	tmp = map[no]
	raise "No bone found in map for #{no}!" unless tmp
	tmp
      end

    end

    int32 :cloth_wind_num
    register_field :cloth_wind, ClothWind, count: 'cloth_wind_num'

    def was_big?
      @__was_big
    end

    def remap(map)
      @cloth_wind.each { |c|
        c.remap(map)
      }
    end

    def self.load_bxm(input_name)
      bxm = BXMFile::load(input_name)
      clw = self::new

      doc = bxm.to_xml
      clw.cloth_wind_num = doc.at_css("//CLOTH_WIND//CLOTH_WIND_NUM").content.to_i

      clw.cloth_wind = doc.css("//CLOTH_WIND//CLOTH_WIND_WK").collect { |c|
        ClothWind.from_bxm_cloth_wind(c)
      }
      clw
    end

    def self.is_big?(f)
      f.rewind
      f.size
      block = lambda { |int|
        num = f.read(4).unpack(int).first
        ( num >= 0 ) && ( num < 256 )
      }
      big = block.call("l>")
      f.rewind
      small = block.call("l<")
      f.rewind
      raise "Invalid data!" unless big ^ small
      return big
    end

    def self.convert(input_name, output_name, output_big = false)
      if input_name.respond_to?(:read) && input_name.respond_to?(:seek)
        input = input_name
      else
        input = File.open(input_name, "rb")
      end
      input_big = is_big?(input)

      if output_name.respond_to?(:write) && output_name.respond_to?(:seek)
        output = output_name
      else
        output = File.open(output_name, "wb")
      end
      output.rewind

      clp = self::new
      clp.instance_variable_set(:@__was_big, input_big)
      clp.__convert(input, output, input_big, output_big)

      input.close unless input_name.respond_to?(:read) && input_name.respond_to?(:seek)
      output.close unless output_name.respond_to?(:write) && output_name.respond_to?(:seek)
      clp
    end

    def self.load(input_name)
      if input_name.respond_to?(:read) && input_name.respond_to?(:seek)
        input = input_name
      else
        input = File.open(input_name, "rb")
      end
      input_big = is_big?(input)

      clp = self::new
      clp.instance_variable_set(:@__was_big, input_big)
      clp.__load(input, input_big)
      input.close unless input_name.respond_to?(:read) && input_name.respond_to?(:seek)
      clp
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
