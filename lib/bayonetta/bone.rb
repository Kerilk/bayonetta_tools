module Bayonetta

  class Bone
    attr_accessor :parent
    attr_accessor :children
    attr_accessor :index
    attr_accessor :x, :y, :z
    def initialize( x, y, z)
      @x = x
      @y = y
      @z = z
      @children = []
    end

    def depth
      if parent then
        return parent.depth + 1
      else
        return 0
      end
    end

    def to_s
      "<#{@index}#{@parent ? " (#{@parent.index})" : ""}: #{@x}, #{@y}, #{@z}, d: #{depth}>"
    end

    def inspect
      to_s
    end

    def distance(other)
      d = (@x - other.x)**2 + (@y - other.y)**2 + (@z - other.z)**2
      dd = (depth - other.depth).abs
      [d, dd]
    end

  end

end


