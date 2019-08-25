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
        int32 :call_tree_node_index
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

    class ColTreeNode < DataConverter
      register_field :p1, Position
      register_field :p2, Position
      int32 :left
      int32 :right
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
          flags = parent.__parent.header.flags
          if flags & 0x8 != 0
            return IIndices::convert(input, output, input_big, output_big, parent, index)
          else
            return SIndices::convert(input, output, input_big, output_big, parent, index)
          end
        end

        def self.load(input, input_big, parent, index)
          flags = parent.__parent.header.flags
          if flags & 0x8 != 0
            return IIndices::load(input, input_big, parent, index)
          else
            return SIndices::load(input, input_big, parent, index)
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
      register_field :vertexes, 'get_vertex_types[0]', count: 'header\num_vertexes', offset: 'header\offset_vertexes'
      register_field :vertexes_ex_data, 'get_vertex_types[1]', count: 'header\num_vertexes',
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

    class Unknown1 < DataConverter
      uint32 :data, count: 6
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
      int16  :flags
      int16  :u_c
      float  :bounding_box, count: 6
      info_pair :info_bones
      info_pair :info_bone_index_translate_table
      info_pair :info_vertex_groups
      info_pair :info_batches
      info_pair :info_lods
      info_pair :info_col_tree_nodes
      info_pair :info_bone_map
      info_pair :info_bone_sets
      info_pair :info_materials
      info_pair :info_meshes
      info_pair :info_mesh_material_pairs
      info_pair :info_unknown1
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
    register_field :col_tree_nodes, ColTreeNode, count: 'header\info_col_tree_nodes\number',
                   offset: 'header\info_col_tree_nodes\offset'
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
    register_field :unknown1, Unknown1, count: 'header\info_unknown1\number',
                   offset: 'header\info_unknown1\offset'

    def delete_meshes(list)
      kept_meshes = @meshes.size.times.to_a - list
      new_mesh_map = kept_meshes.each_with_index.to_h
      if @meshes
        @meshes = kept_meshes.collect { |i|
          @meshes[i]
        }
        @header.info_meshes.number = @meshes.size
      end
      if @mesh_material_pairs
        @mesh_material_pairs = @mesh_material_pairs.select { |pair|
          ! list.include?(pair.mesh_index)
        }
        @header.info_mesh_material_pairs.number = @mesh_material_pairs.size
        @mesh_material_pairs.each { |pair|
          pair.mesh_index = new_mesh_map[pair.mesh_index]
        }
      end
      if @lods && @batches
        batch_indexes = @header.info_batches.number.times.to_a
        filtered_batches = Set::new
        @lods.each { |lod|
          if lod.batch_infos
            lod.batch_infos.each_with_index { |batch_info, index|
              if list.include?(batch_info.mesh_index)
                filtered_batches.add( index + lod.header.batch_start )
              end
            }
            lod.batch_infos = lod.batch_infos.select { |batch_info|
              ! list.include?(batch_info.mesh_index)
            }
            lod.header.num_batch_infos = lod.batch_infos.size
            lod.batch_infos.each { |batch_info|
              batch_info.mesh_index = new_mesh_map[batch_info.mesh_index]
            }
          end
        }
        batch_indexes -= filtered_batches.to_a
        batch_index_map = batch_indexes.each_with_index.to_h
        @batches = batch_indexes.collect { |index|
          @batches[index]
        }
        @header.info_batches.number = @batches.size
        @lods.each { |lod|
          if lod.batch_infos
            lod.header.batch_start = batch_index_map[lod.header.batch_start]
          end
        }
      end
      self
    end

    def delete_batches(batch_list)
      if @lods && @batches
        batch_indexes = @header.info_batches.number.times.to_a
        batch_indexes -= batch_list
        batch_index_map = batch_indexes.each_with_index.to_h
        @batches = batch_indexes.collect { |index|
          @batches[index]
        }
        @header.info_batches.number = @batches.size
        @lods.each { |lod|
          if lod.batch_infos
            new_batch_infos = []
            lod.batch_infos.each_with_index { |batch_info, index|
              unless batch_list.include?(lod.header.batch_start + index)
                new_batch_infos.push batch_info
              end
              lod.batch_infos = new_batch_infos
              lod.header.num_batch_infos = lod.batch_infos.size
            }
          end
        }
        @lods.each { |lod|
          if lod.batch_infos
            lod.header.batch_start = batch_index_map[lod.header.batch_start]
          end
        }
      end
    end

    def recompute_layout
      last_offset = 0x88

      if @header.info_bones.number > 0
        last_offset = @header.info_bones.offset = align(last_offset, 0x10)
        last_offset += @bones.first.size * @header.info_bones.number
      else
        @header.info_bones.offset = 0x0
      end

      if @header.info_bones.number > 0
        last_offset = @header.info_bone_index_translate_table.offset = align(last_offset, 0x10)
        last_offset += @bone_index_translate_table.size
      else
        @header.info_bone_index_translate_table.offset = 0x0
      end

      if @header.info_vertex_groups.number > 0
        last_offset = @header.info_vertex_groups.offset = align(last_offset, 0x4)
        last_offset += @vertex_groups.first.header.size * @header.info_vertex_groups.number
        @vertex_groups.each { |vg|
          if vg.header.num_vertexes > 0
            last_offset = vg.header.offset_vertexes = align(last_offset, 0x10)
            last_offset += vg.header.vertex_size * vg.header.num_vertexes
            if vg.header.vertex_ex_data_size > 0
              last_offset = vg.header.offset_vertexes_ex_data = align(last_offset, 0x10)
              last_offset += vg.header.vertex_ex_data_size * vg.header.num_vertexes
            end
          end
          if vg.header.num_indices > 0
            last_offset = vg.header.offset_indices = align(last_offset, 0x10)
            last_offset += (@header.flags & 0x8 > 0 ? 4 : 2) * vg.header.num_indices
          end
        }
      else
        @header.info_vertex_groups.offset = 0x0
      end

      if @header.info_batches.number > 0
        last_offset = @header.info_batches.offset = align(last_offset, 0x4)
        last_offset += @batches.first.size * @header.info_batches.number
      else
        @header.info_batches.offset = 0x0
      end

      if @header.info_lods.number > 0
        last_offset = @header.info_lods.offset = align(last_offset, 0x4)
        last_offset += @lods.first.header.size * @header.info_lods.number
        @lods.each { |lod|
          if lod.header.num_batch_infos > 0
            lod.header.offset_batch_infos = last_offset
            last_offset += lod.batch_infos.first.size * lod.header.num_batch_infos
          end
          lod.header.offset_name = last_offset
          last_offset += lod.name.size
        }
      else
        @header.info_lods.offset = 0x0
      end

      if @header.info_mesh_material_pairs.number > 0
        last_offset = @header.info_mesh_material_pairs.offset = align(last_offset, 0x10)
        last_offset += @mesh_material_pairs.first.size * @header.info_mesh_material_pairs.number
      else
        @header.info_mesh_material_pairs.offset = 0x0
      end

      if @header.info_col_tree_nodes.number > 0
        last_offset = @header.info_col_tree_nodes.offset = align(last_offset, 0x10)
        last_offset += @col_tree_nodes.first.size * @header.info_col_tree_nodes.number
      else
        @header.info_col_tree_nodes.offset = 0x0
      end

      if @header.info_bone_sets.number > 0
        last_offset = @header.info_bone_sets.offset = align(last_offset, 0x10)
        last_offset += 0x8 * @header.info_bone_sets.number
        @bone_sets.each { |bone_set|
          last_offset = bone_set.offset_bone_indices = align(last_offset, 0x10)
          last_offset += 0x2 * bone_set.num_bone_indices
        }
      else
        @header.info_bone_sets.offset = 0x0
      end

      if @header.info_bone_map.number > 0
        last_offset = @header.info_bone_map.offset = align(last_offset, 0x10)
        last_offset += 0x4 * @header.info_bone_map.number
      else
        @header.info_bone_map.offset = 0x0
      end

      if @header.info_meshes.number > 0
        last_offset = @header.info_meshes.offset = align(last_offset, 0x4)
        last_offset += @meshes.first.header.size * @header.info_meshes.number
        @meshes.each { |mesh|
          mesh.header.offset_name = last_offset
          last_offset += mesh.name.size
          if mesh.header.num_materials > 0
            mesh.header.offset_materials = last_offset
            last_offset += 0x2 * mesh.header.num_materials
          else
            mesh.header.offset_materials = 0x0
          end
          if mesh.header.num_bones_indices > 0
            mesh.header.offset_bones_indices = last_offset
            last_offset += 0x2 * mesh.header.num_bones_indices
          else
            mesh.header.offset_bones_indices = 0x0
          end
        }
      else
        @header.info_meshes.offset = 0x0
      end

      if @header.info_materials.number > 0
        last_offset = @header.info_materials.offset = align(last_offset, 0x10)
        last_offset += @materials.first.header.size * @header.info_materials.number
        @materials.each { |material|
          material.header.offset_name = last_offset
          last_offset += material.name.size
          material.header.offset_shader_name = last_offset
          last_offset += material.shader_name.size
          material.header.offset_technique_name = last_offset
          last_offset += material.technique_name.size
          if material.header.num_textures > 0
            material.header.offset_textures = last_offset
            last_offset += 0x8 * material.header.num_textures
            material.textures.each { |texture|
              texture.offset_name = last_offset
              last_offset += texture.name.size
            }
          else
            material.header.offset_textures = 0x0
          end
          if material.header.num_parameters_groups > 0
            last_offset = material.header.offset_parameters_groups = align(last_offset, 0x10)
            last_offset += 0xC * material.header.num_parameters_groups
            material.parameters_groups.each { |parameter_group|
              last_offset = parameter_group.offset_parameters = align(last_offset, 0x10)
              last_offset += 0x4 * parameter_group.num_parameters
            }
          else
            material.header.offset_parameters_group = 0x0
          end
          if material.header.num_variables > 0
            last_offset = material.header.offset_variables = align(last_offset, 0x10)
            last_offset += 0x8 * material.header.num_variables
            material.variables.each { |variable|
              variable.offset_name = last_offset
              last_offset += variable.name.size
            }
          else
            material.header.offset_variables = 0x0
          end
        }
      else
        @header.info_materials.offset = 0x0
      end

      if @header.info_unknown1.number > 0
        last_offset = @header.info_unknown1.offset = align(last_offset, 0x4)
        last_offset += @unknown1.first.size * @header.info_unknown1.number
      else
        @header.info_unknown1.offset = 0x0
      end

    end

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

    def dump_bones(list = nil)
      bone_struct = Struct::new(:index, :parent, :relative_position, :position, :global_index, :symmetric, :flag)
      list = (0...@header.num_bones) unless list
      list.collect { |bi|
        bone_struct::new(bi, @bones[bi].parent_index, @bones[bi].local_position, @bones[bi].position,
                         @bones[bi].id, -1, 5)
      }
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
