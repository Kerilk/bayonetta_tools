module Bayonetta

  module Linalg

    class Matrix
      attr_reader :data
      def initialize
        @data = [[1.0, 0.0, 0.0, 0.0],
                 [0.0, 1.0, 0.0, 0.0],
                 [0.0, 0.0, 1.0, 0.0],
                 [0.0, 0.0, 0.0, 1.0]]
      end

      def [](i)
        @data[i]
      end

      def transpose
        m = Matrix::new
        4.times { |i|
          4.times { |j|
            m.data[i][j] = data[j][i]
          }
        }
        m
      end

      def inverse
        m = Matrix::new
        s0 = data[0][0] * data[1][1] - data[1][0] * data[0][1]
        s1 = data[0][0] * data[1][2] - data[1][0] * data[0][2]
        s2 = data[0][0] * data[1][3] - data[1][0] * data[0][3]
        s3 = data[0][1] * data[1][2] - data[1][1] * data[0][2]
        s4 = data[0][1] * data[1][3] - data[1][1] * data[0][3]
        s5 = data[0][2] * data[1][3] - data[1][2] * data[0][3]

        c5 = data[2][2] * data[3][3] - data[3][2] * data[2][3]
        c4 = data[2][1] * data[3][3] - data[3][1] * data[2][3]
        c3 = data[2][1] * data[3][2] - data[3][1] * data[2][2]
        c2 = data[2][0] * data[3][3] - data[3][0] * data[2][3]
        c1 = data[2][0] * data[3][2] - data[3][0] * data[2][2]
        c0 = data[2][0] * data[3][1] - data[3][0] * data[2][1]

        invdet = 1.0 / (s0 * c5 - s1 * c4 + s2 * c3 + s3 * c2 - s4 * c1 + s5 * c0)
        m.data[0][0] = ( data[1][1] * c5 - data[1][2] * c4 + data[1][3] * c3) * invdet
        m.data[0][1] = (-data[0][1] * c5 + data[0][2] * c4 - data[0][3] * c3) * invdet
        m.data[0][2] = ( data[3][1] * s5 - data[3][2] * s4 + data[3][3] * s3) * invdet
        m.data[0][3] = (-data[2][1] * s5 + data[2][2] * s4 - data[2][3] * s3) * invdet

        m.data[1][0] = (-data[1][0] * c5 + data[1][2] * c2 - data[1][3] * c1) * invdet
        m.data[1][1] = ( data[0][0] * c5 - data[0][2] * c2 + data[0][3] * c1) * invdet
        m.data[1][2] = (-data[3][0] * s5 + data[3][2] * s2 - data[3][3] * s1) * invdet
        m.data[1][3] = ( data[2][0] * s5 - data[2][2] * s2 + data[2][3] * s1) * invdet

        m.data[2][0] = ( data[1][0] * c4 - data[1][1] * c2 + data[1][3] * c0) * invdet
        m.data[2][1] = (-data[0][0] * c4 + data[0][1] * c2 - data[0][3] * c0) * invdet
        m.data[2][2] = ( data[3][0] * s4 - data[3][1] * s2 + data[3][3] * s0) * invdet
        m.data[2][3] = (-data[2][0] * s4 + data[2][1] * s2 - data[2][3] * s0) * invdet

        m.data[3][0] = (-data[1][0] * c3 + data[1][1] * c1 - data[1][2] * c0) * invdet
        m.data[3][1] = ( data[0][0] * c3 - data[0][1] * c1 + data[0][2] * c0) * invdet
        m.data[3][2] = (-data[3][0] * s3 + data[3][1] * s1 - data[3][2] * s0) * invdet
        m.data[3][3] = ( data[2][0] * s3 - data[2][1] * s1 + data[2][2] * s0) * invdet
        m
      end

      def +(other)
        if other.kind_of?(Matrix)
          m = Matrix::new
          4.times { |i|
            4.times { |j|
              m.data[i][j] = data[i][j] + other.data[i][j]
            }
          }
          return m
        else
          raise "Invalid argument for matrix add: #{other.inspect}!"
        end
      end

      def *(other)
        if other.kind_of?(Matrix)
          m = Matrix::new
          4.times { |i|
            4.times { |j|
              m.data[i][j] = 0.0
              4.times { |k|
                m.data[i][j] += data[i][k] * other.data[k][j]
              }
            }
          }
          return m
        elsif other.kind_of?(Vector) || (other.kind_of?(Array) && other.length == 4)
          return Vector::new(
            @data[0][0] * other[0] + @data[0][1] * other[1] + @data[0][2] * other[2] + @data[0][3] * other[3],
            @data[1][0] * other[0] + @data[1][1] * other[1] + @data[1][2] * other[2] + @data[1][3] * other[3],
            @data[2][0] * other[0] + @data[2][1] * other[1] + @data[2][2] * other[2] + @data[2][3] * other[3],
            @data[3][0] * other[0] + @data[3][1] * other[1] + @data[3][2] * other[2] + @data[3][3] * other[3]
          )
        elsif other.kind_of?(Numeric)
          m = Matrix::new
          4.times { |i|
            4.times { |j|
              m.data[i][j] = data[i][j] * other
            }
          }
          return m
        else
          raise "Invalid argument for matrix miltiply: #{other.inspect}!"
        end
      end
    end #Matrix

    class Vector

      def initialize(x=0.0, y=0.0, z=0.0, w=1.0)
        @data = [x, y, z, w]
      end

      def [](i)
        return @data[i]
      end

      def []=(i,v)
        return @data[i]=v
      end

      def dup
        self.class::new(x,y,z,w)
      end

      def x
        @data[0]      
      end

      def x=(v)
        @data[0] = v
      end

      def y
        @data[1]
      end

      def y=(v)
        @data[1] = v
      end

      def z
        @data[2]
      end

      def z=(v)
        @data[2]=v
      end

      def w
        @data[3]
      end

      def w=(v)
        @data[3] = v
      end

      def -(other)
        Vector::new(x-other.x, y-other.y, z-other.z, w)
      end

      def +(other)
        Vector::new(x+other.x, y+other.y, z+other.z, w)
      end

      def *(scalar)
        Vector::new(x*scalar, y*scalar, z*scalar, w)
      end

      def dot(other)
        x*other.x + y*other.y + z*other.z
      end

      def -@
        self.class::new(-x, -y, -z, w)
      end

      def length
        Math.sqrt(x*x + y*y + z*z)
      end

      def normalize!
        l = length
        if l != 0.0 && ! l.nan?
          @data[0] /= l
          @data[1] /= l
          @data[2] /= l
        else
          @data[0] = 0.0
          @data[1] = 0.0
          @data[2] = 0.0
        end
        self
      end

      def normalize
        self.dup.normalize!
      end

    end #Vector

    def self.get_translation_vector(*args)
      if args.length == 1
        v = args.first.dup
      elsif args.length == 3
        v = Vector::new(*args)
      else
        raise "Invalid translation arguments: #{args.inspect}!"
      end
      v
    end

    def self.get_translation_matrix(*args)
      m = get_unit_matrix
      v = get_translation_vector(*args)
      m.data[0][3] = v[0]
      m.data[1][3] = v[1]
      m.data[2][3] = v[2]
      m
    end

    def self.get_inverse_translation_matrix(*args)
      m = get_unit_matrix
      v = get_translation_vector(*args)
      m.data[0][3] = -v[0]
      m.data[1][3] = -v[1]
      m.data[2][3] = -v[2]
      m
    end

    def self.get_scaling_vector(*args)
      if args.length == 1
        v = args.first.dup
      elsif args.length == 3
        v = Vector::new(*args)
      else
        raise "Invalid translation arguments: #{args.inspect}!"
      end
      v
    end

    def self.get_scaling_matrix(*args)
      m = get_unit_matrix
      v = get_scaling_vector(*args)
      m.data[0][0] = v[0]
      m.data[1][1] = v[1]
      m.data[2][2] = v[2]
      m
    end

    def self.get_inverse_scaling_matrix(*args)
      m = get_unit_matrix
      v = get_scaling_vector(*args)
      m.data[0][0] = 1.0/v[0]
      m.data[1][1] = 1.0/v[1]
      m.data[2][2] = 1.0/v[2]
      m
    end

    def self.get_rotation_vector(*args)
      if args.length == 1
        v = args.first.dup
      elsif args.length == 3
        v = Vector::new(*args)
      else
        raise "Invalid translation arguments: #{args.inspect}!"
      end
      v
    end

    def self.get_rotation_matrix(*args, center: nil, order: nil)
      v = get_rotation_vector(*args)
      if center
        vt = get_translation_vector(*[center].flatten)
        mt1 = get_translation_matrix(-vt)
        mt2 = get_translation_matrix(vt)
      else
        mt1 = get_unit_matrix
        mt2 = get_unit_matrix
      end
      m = mt2
      if order
        case order
        when 0
          m = m * rotation_matrix( v[0], Vector::new(1.0, 0.0, 0.0))
          m = m * rotation_matrix( v[1], Vector::new(0.0, 1.0, 0.0))
          m = m * rotation_matrix( v[2], Vector::new(0.0, 0.0, 1.0))
        when 1
          m = m * rotation_matrix( v[0], Vector::new(1.0, 0.0, 0.0))
          m = m * rotation_matrix( v[2], Vector::new(0.0, 0.0, 1.0))
          m = m * rotation_matrix( v[1], Vector::new(0.0, 1.0, 0.0))
        when 2
          m = m * rotation_matrix( v[1], Vector::new(0.0, 1.0, 0.0))
          m = m * rotation_matrix( v[0], Vector::new(1.0, 0.0, 0.0))
          m = m * rotation_matrix( v[2], Vector::new(0.0, 0.0, 1.0))
        when 3
          m = m * rotation_matrix( v[1], Vector::new(0.0, 1.0, 0.0))
          m = m * rotation_matrix( v[2], Vector::new(0.0, 0.0, 1.0))
          m = m * rotation_matrix( v[0], Vector::new(1.0, 0.0, 0.0))
        when 4
          m = m * rotation_matrix( v[2], Vector::new(0.0, 0.0, 1.0))
          m = m * rotation_matrix( v[0], Vector::new(1.0, 0.0, 0.0))
          m = m * rotation_matrix( v[1], Vector::new(0.0, 1.0, 0.0))
        else
          m = m * rotation_matrix( v[2], Vector::new(0.0, 0.0, 1.0))
          m = m * rotation_matrix( v[1], Vector::new(0.0, 1.0, 0.0))
          m = m * rotation_matrix( v[0], Vector::new(1.0, 0.0, 0.0))
        end
      else
        m = m * rotation_matrix( v[2], Vector::new(0.0, 0.0, 1.0))
        m = m * rotation_matrix( v[1], Vector::new(0.0, 1.0, 0.0))
        m = m * rotation_matrix( v[0], Vector::new(1.0, 0.0, 0.0))
      end
      m = m * mt1
      m
    end

    def self.get_inverse_rotation_matrix(*args, center: nil, order: nil)
      v = get_rotation_vector(*args)
      if center
        vt = get_translation_vector(*[center].flatten)
        mt1 = get_translation_matrix(-vt)
        mt2 = get_translation_matrix(vt)
      else
        mt1 = get_unit_matrix
        mt2 = get_unit_matrix
      end
      m = mt2
      if order
        case order
        when 0
          m = m * rotation_matrix( -v[2], Vector::new(0.0, 0.0, 1.0))
          m = m * rotation_matrix( -v[1], Vector::new(0.0, 1.0, 0.0))
          m = m * rotation_matrix( -v[0], Vector::new(1.0, 0.0, 0.0))
        when 1
          m = m * rotation_matrix( -v[1], Vector::new(0.0, 1.0, 0.0))
          m = m * rotation_matrix( -v[2], Vector::new(0.0, 0.0, 1.0))
          m = m * rotation_matrix( -v[0], Vector::new(1.0, 0.0, 0.0))
        when 2
          m = m * rotation_matrix( -v[2], Vector::new(0.0, 0.0, 1.0))
          m = m * rotation_matrix( -v[0], Vector::new(1.0, 0.0, 0.0))
          m = m * rotation_matrix( -v[1], Vector::new(0.0, 1.0, 0.0))
        when 3
          m = m * rotation_matrix( -v[0], Vector::new(1.0, 0.0, 0.0))
          m = m * rotation_matrix( -v[2], Vector::new(0.0, 0.0, 1.0))
          m = m * rotation_matrix( -v[1], Vector::new(0.0, 1.0, 0.0))
        when 4
          m = m * rotation_matrix( -v[1], Vector::new(0.0, 1.0, 0.0))
          m = m * rotation_matrix( -v[0], Vector::new(1.0, 0.0, 0.0))
          m = m * rotation_matrix( -v[2], Vector::new(0.0, 0.0, 1.0))
        else
          m = m * rotation_matrix( -v[0], Vector::new(1.0, 0.0, 0.0))
          m = m * rotation_matrix( -v[1], Vector::new(0.0, 1.0, 0.0))
          m = m * rotation_matrix( -v[2], Vector::new(0.0, 0.0, 1.0))
        end
      else
        m = m * rotation_matrix( -v[0], Vector::new(1.0, 0.0, 0.0))
        m = m * rotation_matrix( -v[1], Vector::new(0.0, 1.0, 0.0))
        m = m * rotation_matrix( -v[2], Vector::new(0.0, 0.0, 1.0))
      end
      m = m * mt1
      m
    end

    def self.get_unit_matrix
      Matrix::new
    end

    def self.get_zero_matrix
      Matrix::new * 0.0
    end

    def self.get_transformation_matrix(translate, rotate, scale, parent_scale, order: nil)
      get_translation_matrix(translate) *
      get_inverse_scaling_matrix(parent_scale) *
      get_rotation_matrix(rotate, order: order) *
      get_scaling_matrix(scale)
    end

    def self.get_inverse_transformation_matrix(translate, rotate, scale, parent_scale, order: nil)
      get_inverse_scaling_matrix(scale) *
      get_inverse_rotation_matrix(rotate, order: order) *
      get_scaling_matrix(parent_scale) *
      get_inverse_translation_matrix(translate)
    end

    private

    # https://en.wikipedia.org/wiki/Rotation_matrix#Axis_and_angle
    def self.rotation_matrix(angle, vector)
      v = vector.normalize
      x = v[0]
      y = v[1]
      z = v[2]
      c = Math::cos(angle)
      d = 1 - c
      s = Math::sin(angle)

      m = Matrix::new

      m.data.replace( [ [ x*x*d + c,   x*y*d - z*s, x*z*d + y*s, 0.0],
                        [ y*x*d + z*s, y*y*d + c,   y*z*d - x*s, 0.0],
                        [ z*x*d - y*s, z*y*d + x*s, z*z*d + c,   0.0],
                        [ 0.0,         0.0,         0.0,         1.0] ] ) 
      m
    end

  end #Linalg

end #Bayonetta
