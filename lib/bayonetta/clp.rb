module Bayonetta

  class CLPFile < DataConverter

    class FVector < DataConverter
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

    class Header < DataConverter
      int32 :num
      float :limit_spring_rate
      float :spd_rate
      float :stretchy
      int16 :bundle_num
      int16 :bundle_num_2
      float :thick
      register_field :gravity_vec, FVector
      int32 :gravity_parts_no
      float :first_bundle_rate
      register_field :wind_vec, FVector
      int32 :wind_parts_no
      register_field :wind_offset, FVector
      float :wind_sin
      float :hit_adjust_rate

      def from_bxm_header(h)
        @num = h.at_css("m_Num").content.to_i
        @limit_spring_rate = h.at_css("m_LimitSpringRate").content.to_f
        @spd_rate = h.at_css("m_SpdRate").content.to_f
        @stretchy = h.at_css("m_Stretchy").content.to_f
        @bundle_num = h.at_css("m_BundleNum").content.to_i
        @bundle_num_2 = h.at_css("m_BundleNum2").content.to_i
        @thick = h.at_css("m_Thick").content.to_f
        @gravity_vec = FVector.from_bxm_vector(h.at_css("m_GravityVec").content)
        @gravity_parts_no = h.at_css("m_GravityPartsNo").content.to_i
        @first_bundle_rate = h.at_css("m_FirstBundleRate").content.to_f
        @wind_vec = FVector.from_bxm_vector(h.at_css("m_WindVec").content)
        @wind_parts_no = h.at_css("m_WindPartsNo").content.to_i
        @wind_offset = FVector.from_bxm_vector(h.at_css("m_WindOffset").content)
        @wind_sin = h.at_css("m_WindSin").content.to_f
        @hit_adjust_rate = h.at_css("m_HitAdjustRate").content.to_f
        self
      end

      def self.from_bxm_header(h)
        nh = self::new
        nh.from_bxm_header(h)
        nh
      end

    end

    class Cloth < DataConverter
      int16 :no
      int16 :no_up
      int16 :no_down
      int16 :no_side
      int16 :no_poly
      int16 :no_fix
      float :rot_limit
      register_field :offset, FVector

      def from_bxm_cloth(h)
        @no = h.at_css("no").content.to_i
        @no_up = h.at_css("noUp").content.to_i
        @no_down = h.at_css("noDown").content.to_i
        @no_side = h.at_css("noSide").content.to_i
        @no_poly = h.at_css("noPoly").content.to_i
        @no_fix = h.at_css("noFix").content.to_i
        @rot_limit = h.at_css("rotLimit").content.to_f
        @offset = FVector.from_bxm_vector(h.at_css("offset").content)
        self
      end

      def self.from_bxm_cloth(c)
        cl = self::new
        cl.from_bxm_cloth(c)
        cl
      end

      def remap(map, poly = true, fix = true)
        @no = map[@no]
        @no_up = map[@no_up]
        @no_down = map[@no_down]
        @no_side = map[@no_side]
        @no_poly = ( poly ? map[@no_poly] : 4095 )
        @no_fix = ( fix ? map[@no_fix] : 4095 )
      end
    end

    register_field :header, Header
    register_field :cloth, Cloth, count: 'header\num'

    def was_big?
      @__was_big
    end

    def remap(map, poly = true, fix = true)
      @cloth.each { |c|
        c.remap(map, poly, fix)
      }
    end

    def self.load_bxm(input_name)
      bxm = BXMFile::load(input_name)
      clp = self::new

      doc = bxm.to_xml
      h = doc.at_css("//CLOTH//CLOTH_HEADER")
      clp.header = Header.from_bxm_header(h)

      clp.cloth = doc.css("//CLOTH//CLOTH_WK").collect { |c|
        Cloth.from_bxm_cloth(c)
      }
      clp
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
      clp.convert(input, output, input_big, output_big)

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
      clp.load(input, input_big)
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

      set_dump_type(output, output_big, nil, nil)
      dump_fields
      unset_dump_type

      output.close unless output_name.respond_to?(:write) && output_name.respond_to?(:seek)
      self
    end

  end

end
