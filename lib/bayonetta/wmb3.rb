module Bayonetta
  class WMB3File < DataConverter

    class MeshMaterialPair < DataConverter
      uint32 :mesh_index
      uint32 :material_index
    end

    class Mesh < DataConverter
      class Header < DataConverter
        uint32 :offset_name
        float  :bounding_box, count: 6
        uint32 :offset_materials
        uint32 :num_materials
        uint32 :offset_bones_indices
        uint32 :num_bones_indices
      end
      register_field :header, Header
      string :name, offset: 'header\offset_name'
      uint16 :materials, count: 'header\num_materials', offset: 'header\offset_materials'
      uint16 :bone_indices, count: 'header\num_bones_indices', offset: 'header\offset_bones_indices'
    end

    class Material < DataConverter

      class Variable < DataConverter
        uint32 :offset_name
        float :value
        string :name, offset: 'offset_name'
      end

      class ParameterGroup < DataConverter
        int32 :index
        uint32 :offset_parameters
        uint32 :num_parameters
        float :parameters, count: 'num_parameters', offset: 'offset_parameters'
      end

      class Texture < DataConverter
        uint32 :offset_name
        uint32 :texture_id
        string :name, offset: 'offset_name'
      end

      class Header < DataConverter
        uint16 :date, count: 4
        uint32 :offset_name
        uint32 :offset_shader_name
        uint32 :offset_technique_name
        uint32 :u_a
        uint32 :offset_textures
        uint32 :num_textures
        uint32 :offset_parameters_groups
        uint32 :num_parameters_groups
        uint32 :offset_variables
        uint32 :num_variables
      end
      register_field :header, Header
      string :name, offset: 'header\offset_name'
      string :shader_name, offset: 'header\offset_shader_name'
      string :technique_name, offset: 'header\offset_technique_name'
      register_field :textures, Texture, count: 'header\num_textures', sequence: true,
                     offset: 'header\offset_textures + __iterator * 8'
      register_field :parameters_groups, ParameterGroup, count: 'header\num_parameters_groups',
                     sequence: true, offset: 'header\offset_parameters_groups + __iterator * 12'
      register_field :variables, Variable, count: 'header\num_variables', sequence: true,
                     offset: 'header\offset_variables + __iterator * 8'

    end

    class BoneSet < DataConverter
      uint32 :offset_bone_indices
      uint32 :num_bone_indices
      int16 :bone_indices, count: 'num_bone_indices', offset: 'offset_bone_indices'
    end

    class Lod < DataConverter

      class BatchInfo < DataConverter
        uint32 :vertex_group_index
        uint32 :mesh_index
        uint32 :material_index
        int32 :u_a
        uint32 :mesh_material_index
        int32 :u_b
      end

      class Header < DataConverter
        uint32 :offset_name
        int32 :lod_level
        uint32 :batch_start
        uint32 :offset_batch_infos
        uint32 :num_batch_infos
      end
      register_field :header, Header
      string :name, offset: 'header\offset_name'
      register_field :batch_infos, BatchInfo, count: 'header\num_batch_infos', offset: 'header\offset_batch_infos'
    end

    class Batch < DataConverter
      uint32 :vertex_group_index
      int32 :bone_set_index
      uint32 :vertex_start
      uint32 :index_start
      uint32 :num_vertexes
      uint32 :num_indices
      uint32 :num_primitives
    end

    VERTEX_TYPES = {}
    VERTEX_TYPES.update( YAML::load_file(File.join( File.dirname(__FILE__), 'vertex_types_nier.yaml')) )

    class VertexExData < DataConverter

      def self.convert(input, output, input_big, output_big, parent, index)
        return parent.get_vertex_types[1]::convert(input, output, input_big, output_big, parent, index)
      end

      def self.load(input, input_big, parent, index)
        return parent.get_vertex_types[1]::load(input, input_big, parent, index)
      end

    end

    class Vertex < DataConverter

      def self.convert(input, output, input_big, output_big, parent, index)
        return parent.get_vertex_types[0]::convert(input, output, input_big, output_big, parent, index)
      end

      def self.load(input, input_big, parent, index)
        return parent.get_vertex_types[0]::load(input, input_big, parent, index)
      end

    end

    class VertexGroup < DataConverter

      def is_bayo2? #UByteList are arrays of char really
        true
      end

      def get_vertex_fields
        if @vertex_fields
          return @vertex_fields
        else
          types = VERTEX_TYPES[ @header.vertex_flags ]
          @vertex_fields = []
          if types[0]
            types[0].each { |name, type|
              @vertex_fields.push(name)
            }
          end
          if types[1]
            types[1].each { |name, type|
              @vertex_fields.push(name)
            }
          end
          return @vertex_fields
        end
      end

      def get_vertex_types
        if @vertex_type
          return [@vertex_type, @vertex_ex_type]
        else
          types = VERTEX_TYPES[ @header.vertex_flags ]
          @vertex_type = Class::new(DataConverter)
          @vertex_size = 0
          if types[0]
            types[0].each { |name, type|
              @vertex_type.register_field(name, VERTEX_FIELDS[type][0])
              @vertex_size += VERTEX_FIELDS[type][1]
            }
          end
          raise "Invalid size for ex data #{@vertex_size} != #{@header.vertex_size}!" if @vertex_size != @header.vertex_size
          @vertex_ex_type = Class::new(DataConverter)
          @vertex_ex_size = 0
          if types[1]
            types[1].each { |name, type|
              @vertex_ex_type.register_field(name, VERTEX_FIELDS[type][0])
              @vertex_ex_size += VERTEX_FIELDS[type][1]
            }
          end
          raise "Invalid size for ex data #{@vertex_ex_size} != #{@header.vertex_ex_data_size}!" if @vertex_ex_size != @header.vertex_ex_data_size
          return [@vertex_type, @vertex_ex_type]
        end
      end

      def get_vertex_field(field, vi)
        if @vertexes[vi].respond_to?(field)
          return @vertexes[vi].send(field)
        elsif @vertexes_ex_data && @vertexes_ex_data[vi].respond_to?(field)
          return @vertexes_ex_data[vi].send(field)
        else
          return nil
        end
      end

      def set_vertex_field(field, vi, val)
        if @vertexes[vi].respond_to?(field)
          return @vertexes[vi].send(:"#{field}=", val)
        elsif @vertexes_ex_data && @vertexes_ex_data[vi].respond_to?(field)
          return @vertexes_ex_data[vi].send(:"#{field}=", val)
        else
          raise "Couldn't find field: #{field}!"
        end
      end

      class IIndices < DataConverter
        uint32 :values, count: '..\header\num_indices', offset: '..\header\offset_indices'
      end

      class SIndices < DataConverter
        uint16 :values, count: '..\header\num_indices', offset: '..\header\offset_indices'
      end

      class Indices < DataConverter

        def self.convert(input, output, input_big, output_big, parent, index)
          u_b = parent.__parent.header.u_b
          case u_b
          when 0xa, 0x8
            return IIndices::convert(input, output, input_big, output_big, parent, index)
          when 0x2
            return SIndices::convert(input, output, input_big, output_big, parent, index)
          else
            raise "Unknow u_b: #{u_b}!"
          end
        end

        def self.load(input, input_big, parent, index)
          u_b = parent.__parent.header.u_b
          case u_b
          when 0xa, 0x8
            return IIndices::load(input, input_big, parent, index)
          when 0x2
            return SIndices::load(input, input_big, parent, index)
          else
            raise "Unknow u_b: #{u_b}!"
          end
        end

      end

      class Header < DataConverter
        uint32 :offset_vertexes
        uint32 :offset_vertexes_ex_data
        uint32 :u_a
        uint32 :u_b
        uint32 :vertex_size
        uint32 :vertex_ex_data_size
        uint32 :u_c
        uint32 :u_d
        uint32 :num_vertexes
        uint32 :vertex_flags
        uint32 :offset_indices
        uint32 :num_indices
      end
      register_field :header, Header
      register_field :vertexes, Vertex, count: 'header\num_vertexes', offset: 'header\offset_vertexes'
      register_field :vertexes_ex_data, VertexExData, count: 'header\num_vertexes',
                     offset: 'header\offset_vertexes_ex_data'
      register_field :indices, Indices
    end

    class Bone < DataConverter
      int16 :id
      int16 :parent_index
      register_field :local_position, Position
      register_field :local_rotation, Position
      register_field :local_scale, Position
      register_field :position, Position
      register_field :rotation, Position
      register_field :scale, Position
      register_field :t_position, Position
    end

    class InfoPair < DataConverter
      uint32 :offset
      uint32 :number
    end

    class Header < DataConverter
      def self.info_pair(field, count: nil, offset: nil, sequence: false, condition: nil)
        register_field(field, InfoPair, count: count, offset: offset, sequence: sequence, condition: condition)
      end

      uint32 :id
      uint32 :version
      int32  :u_a
      int16  :u_b
      int16  :u_c
      float  :bounding_box, count: 6
      info_pair :info_bones
      info_pair :info_bone_index_translate_table
      info_pair :info_vertex_groups
      info_pair :info_batches
      info_pair :info_lods
      info_pair :info_u_d
      info_pair :info_bone_map
      info_pair :info_bone_sets
      info_pair :info_materials
      info_pair :info_meshes
      info_pair :info_mesh_material_pairs
      info_pair :info_u_e
    end

    register_field :header, Header
    register_field :bones, Bone, count: 'header\info_bones\number',
                   offset: 'header\info_bones\offset'
    register_field :bone_index_translate_table, BoneIndexTranslateTable,
                   offset: 'header\info_bone_index_translate_table\offset'
    register_field :vertex_groups, VertexGroup, count: 'header\info_vertex_groups\number',
                   sequence: true, offset: 'header\info_vertex_groups\offset + __iterator * 48'
    register_field :batches, Batch, count: 'header\info_batches\number',
                   offset: 'header\info_batches\offset'
    register_field :lods, Lod, count: 'header\info_lods\number', sequence: true,
                   offset: 'header\info_lods\offset + __iterator * 20'
    uint32         :bone_map, count: 'header\info_bone_map\number',
                   offset: 'header\info_bone_map\offset'
    register_field :bone_sets, BoneSet, count: 'header\info_bone_sets\number', sequence: true,
                   offset: 'header\info_bone_sets\offset + __iterator * 8'
    register_field :materials, Material, count: 'header\info_materials\number', sequence: true,
                   offset: 'header\info_materials\offset + __iterator * 48'
    register_field :meshes, Mesh, count: 'header\info_meshes\number', sequence: true,
                   offset: 'header\info_meshes\offset + __iterator * 44'
    register_field :mesh_material_pairs, MeshMaterialPair,
                   count: 'header\info_mesh_material_pairs\number',
                   offset: 'header\info_mesh_material_pairs\offset'

    def was_big?
      @__was_big
    end

    def get_vertex_field(field, vg, vi)
      @vertex_groups[vg].get_vertex_field(field, vi)
    end

    def set_vertex_field(field, vg, vi, val)
      @vertex_groups[vg].set_vertex_field(field, vi, val)
    end

    def scale(s)
      @vertex_groups.each { |vg|
        if vg.vertexes && vg.vertexes.first.respond_to?(:position)
          vg.vertexes.each { |v|
            v.position.x = v.position.x * s
            v.position.y = v.position.y * s
            v.position.z = v.position.z * s
          }
        end
      }
      @bones.each { |b|
        b.position.x = b.position.x * s
        b.position.y = b.position.y * s
        b.position.z = b.position.z * s
        b.local_position.x = b.local_position.x * s
        b.local_position.y = b.local_position.y * s
        b.local_position.z = b.local_position.z * s
        b.t_position.x = b.t_position.x * s
        b.t_position.y = b.t_position.y * s
        b.t_position.z = b.t_position.z * s
      }
      self
    end

    def get_vertex_usage
      vertex_usage = Hash::new { |h, k| h[k] = [] }
      @batches.each { |b|
        @vertex_groups[b.vertex_group_index].indices.values[b.index_start...(b.index_start+b.num_indices)].each { |i|
          vertex_usage[[b.vertex_group_index, i]].push( b )
        }
      }
      vertex_usage.each { |k,v| v.uniq! }
      vertex_usage
    end

    def recompute_relative_positions
      @bones.each { |b|
        if b.parent_index != -1
          b.local_position = b.position - @bones[b.parent_index].position
        else
          b.local_position = b.position
        end
      }
      self
    end

    def set_tpose
      inverse_bind_pose = @bones.collect { |b|
        Linalg::get_inverse_transformation_matrix(b.position, b.rotation, b.scale)
      }
      target_pose = @bones.collect { |b|
        Linalg::get_translation_matrix(b.t_position)
      }
      bones.each { |b|
        b.position = b.t_position
        b.rotation.x = 0.0
        b.rotation.y = 0.0
        b.rotation.z = 0.0
        b.scale.x = 1.0
        b.scale.y = 1.0
        b.scale.z = 1.0
        b.local_rotation.x = 0.0
        b.local_rotation.y = 0.0
        b.local_rotation.z = 0.0
        b.local_scale.x = 1.0
        b.local_scale.y = 1.0
        b.local_scale.z = 1.0
      }
      multiplied_matrices = target_pose.each_with_index.collect { |m, i|
        m * inverse_bind_pose[i]
      }
      vertex_usage = get_vertex_usage
      vertex_usage.each { |(vgi, vi), bs|
        if bs.first.bone_set_index >= 0
          bone_set = bone_sets[bs.first.bone_set_index].bone_indices
          bone_refs = bone_set.collect { |bi| @bone_map[bi] }
        else
          bone_refs = @bone_map
        end
        bone_infos = get_vertex_field(:bone_infos, vgi, vi)
        indexes_and_weights = bone_infos.get_indexes_and_weights
        vertex_matrix = Linalg::get_zero_matrix
        indexes_and_weights.each { |bi, bw|
          i = bone_refs[bi]
          vertex_matrix = vertex_matrix + multiplied_matrices[i] * (bw.to_f/255.to_f)
        }
        vp = get_vertex_field(:position, vgi, vi)
        new_vp = vertex_matrix * Linalg::Vector::new(vp.x, vp.y, vp.z)
        vp.x = new_vp.x
        vp.y = new_vp.y
        vp.z = new_vp.z
        n = get_vertex_field(:normal, vgi, vi)
        new_n = vertex_matrix * Linalg::Vector::new(n.x, n.y, n.z, 0.0)
        n.x = new_n.x
        n.y = new_n.y
        n.z = new_n.z
        t = get_vertex_field(:tangents, vgi, vi)
        new_t = vertex_matrix * Linalg::Vector::new(t.x, t.y, t.z, 0.0)
        t.x = new_t.x
        t.y = new_t.y
        t.z = new_t.z
      }
      self
    end

    def self.load(input_name)
      if input_name.respond_to?(:read) && input_name.respond_to?(:seek)
        input = input_name
      else
        input = File.open(input_name, "rb")
      end
      wmb = self::new
      wmb.instance_variable_set(:@__was_big, false)
      wmb.load(input, false)
      input.close unless input_name.respond_to?(:read) && input_name.respond_to?(:seek)
      wmb
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
