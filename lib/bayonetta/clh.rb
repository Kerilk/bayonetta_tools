module Bayonetta

  class CLHFile < DataConverter

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

    class ClothAT < DataConverter
      int16 :p1
      int16 :p2
      float :weight
      float :radius
      register_field :offset1, FVector
      register_field :offset2, FVector

      def from_bxm_cloth_at(h)
        @p1 = h.at_css("p1").content.to_i
        @p2 = h.at_css("p2").content.to_i
        @weight = h.at_css("weight").content.to_f
        @radius = h.at_css("radius").content.to_f
        @offset1 = FVector.from_bxm_vector(h.at_css("offset1").content)
        @offset2 = FVector.from_bxm_vector(h.at_css("offset2").content)
        self
      end

      def self.from_bxm_cloth_at(c)
        clat = self::new
        clat.from_bxm_cloth_at(c)
        clat
      end

      def remap(map)
        @p1 = check_and_remap_bone(map, @p1)
        @p2 = check_and_remap_bone(map, @p2)
      end

      private
      def check_and_remap_bone(map, no)
        tmp = map[no]
        raise "No bone found in map for #{no}!" unless tmp
        tmp
      end

    end

    int32 :cloth_at_num
    register_field :cloth_at, ClothAT, count: 'cloth_at_num'

    def was_big?
      @__was_big
    end

    def remap(map)
      @cloth_at.each { |c|
        c.remap(map)
      }
    end

    def self.load_bxm(input_name)
      bxm = BXMFile::load(input_name)
      clat = self::new

      doc = bxm.to_xml
      clat.cloth_at_num = doc.at_css("//CLOTH_AT//CLOTH_AT_NUM").content.to_i

      clat.cloth_at = doc.css("//CLOTH_AT//CLOTH_AT_WK").collect { |c|
        ClothAT.from_bxm_cloth_at(c)
      }
      clat
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
