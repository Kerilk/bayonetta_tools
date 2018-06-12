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
