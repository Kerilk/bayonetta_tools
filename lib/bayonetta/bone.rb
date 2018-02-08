module Bayonetta

  class Bone
    attr_accessor :parent
    attr_accessor :children
    attr_accessor :index
    attr_accessor :position
    attr_accessor :relative_position
    attr_accessor :symmetric
    attr_accessor :flag
    def initialize( position )
      @position = position
      @children = []
      @parent = nil
      @relative_position = nil
      @symmetric = nil
      @flag = nil
      @index = nil
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
      d = (@position.xf - other.position.xf)**2 +
          (@position.yf - other.position.yf)**2 +
          (@position.zf - other.position.zf)**2
      d = Math::sqrt(d)
      dd = (depth - other.depth).abs
      [d, dd]
    end

    def parents
      return [] unless parent
      return [parent] + parent.parents
    end

  end

end


