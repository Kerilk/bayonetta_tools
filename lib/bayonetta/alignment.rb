module Bayonetta

  module Alignment

    def align(val, alignment)
      remainder = val % alignment
      val += alignment - remainder if remainder > 0
      val
    end
    private :align

  end

end
