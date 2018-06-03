module Bayonetta

  module Endianness

    def get_uint(big = @big)
      uint = "L"
      if big
        uint <<= ">"
      else
        uint <<= "<"
      end
      uint
    end
    private :get_uint

    def get_float(big = @big)
      if big
        flt = "g"
      else
        flt = "e"
      end
      flt
    end

    private :get_float

    def get_short(big = @big)
      sh = "s"
      if big
        sh <<= ">"
      else
        sh <<="<"
      end
      sh
    end

    private :get_short

    def get_ushort(big = @big)
      sh = "S"
      if big
        sh <<= ">"
      else
        sh <<="<"
      end
      sh
    end

    private :get_ushort

  end

 end
