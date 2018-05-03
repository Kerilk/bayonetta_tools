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
        elsif other.kind_of?(Vector)
          return Vector::new(
            @data[0][0] * other.x + @data[0][1] * other.y + @data[0][2] * other.z + @data[0][3] * other.w,
            @data[1][0] * other.x + @data[1][1] * other.y + @data[1][2] * other.z + @data[1][3] * other.w,
            @data[2][0] * other.x + @data[2][1] * other.y + @data[2][2] * other.z + @data[2][3] * other.w,
            @data[3][0] * other.x + @data[3][1] * other.y + @data[3][2] * other.z + @data[3][3] * other.w
          )
        else
          raise "Invalid argument for matrix miltiply: #{other.inspect}!"
        end
      end
    end #Matrix

    class Vector

      def initialize(x=0.0, y=0.0, z=0.0, w=1.0)
        @data = [x, y, z, w]
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

      def -@
        self.class::new(-x, -y, -z, w)
      end

      def normalize!
        l = Math::sqrt(x*x + y*y + z*z)
        @data[0] /= l
        @data[1] /= l
        @data[2] /= l
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
      m = Matrix::new
      v = get_translation_vector(*args)
      m.data[0][3] = v.x
      m.data[1][3] = v.y
      m.data[2][3] = v.z
      m
    end

    #rotation matrix using the same convention as bayonetta motions (-rx around the x axis then ry around the y axis then -rz around the z axis) (use radians)
    def self.get_rotation_matrix(rx, ry, rz, center: nil)
      if center
        vt = get_translation_vector(*[center].flatten)
        mt1 = get_translation_matrix(-vt)
        mt2 = get_translation_matrix(vt)
      else
        mt1 = get_unit_matrix
        mt2 = get_unit_matrix
      end
      m = mt2
      m = m * rotation_matrix(-rz, Vector::new(0.0, 0.0, 1.0))
      m = m * rotation_matrix( ry, Vector::new(0.0, 1.0, 0.0))
      m = m * rotation_matrix(-rx, Vector::new(1.0, 0.0, 0.0))
      m = m * mt1
      m
    end

    def self.get_unit_matrix
      Matrix::new
    end
 
    private

    # https://en.wikipedia.org/wiki/Rotation_matrix#Axis_and_angle
    def self.rotation_matrix(angle, vector)
      v = vector.normalize
      x = v.x
      y = v.y
      z = v.z
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
