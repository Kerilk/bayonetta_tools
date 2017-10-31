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

  end

 end
