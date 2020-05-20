# frozen_string_literal: true

module RuboCop
  module Cop
    module GraphQL
      # This cop checks consistency of field definitions
      #
      # EnforcedStyle supports two modes:
      #
      # `group_definitions` : all field definitions should be grouped together.
      #
      # `define_resolver_after_definition` : if resolver method exists it should
      # be defined right after the field definition.
      #
      # @example EnforcedStyle: group_definitions (default)
      #   # good
      #
      #   class UserType < BaseType
      #     field :first_name, String, null: true
      #     field :last_name, String, null: true
      #
      #     def first_name
      #       object.contact_data.first_name
      #     end
      #
      #     def last_name
      #       object.contact_data.last_name
      #     end
      #   end
      #
      # @example EnforcedStyle: define_resolver_after_definition
      #   # good
      #
      #   class UserType < BaseType
      #     field :first_name, String, null: true
      #
      #     def first_name
      #       object.contact_data.first_name
      #     end
      #
      #     field :last_name, String, null: true
      #
      #     def last_name
      #       object.contact_data.last_name
      #     end
      #   end
      class FieldDefinitions < Cop
        include ConfigurableEnforcedStyle

        def_node_matcher :field_definition?, <<~PATTERN
          (send nil? :field ...)
        PATTERN

        def_node_matcher :field_name, <<~PATTERN
          (send nil? :field (:sym $...) ...)
        PATTERN

        def_node_matcher :field_kwargs, <<~PATTERN
          (send nil? :field
            ...
            (hash
              $...
            )
          )
        PATTERN

        def_node_matcher :resolver_option?, <<~PATTERN
          (pair (sym :resolver) ...)
        PATTERN

        def_node_matcher :method_option?, <<~PATTERN
          (pair (sym :method) ...)
        PATTERN

        def_node_matcher :hash_key_option?, <<~PATTERN
          (pair (sym :hash_key) ...)
        PATTERN

        def_node_matcher :resolver_method_option, <<~PATTERN
          (pair (sym :resolver_method) (sym $...))
        PATTERN

        def on_send(node)
          return unless field_definition?(node)

          case style
          when :group_definitions
            check_grouped_field_declarations(node.parent)
          when :define_resolver_after_definition
            check_resolver_is_defined_after_definition(node)
          end
        end

        private

        GROUP_DEFS_MSG = "Group all field definitions together."

        def check_grouped_field_declarations(node)
          fields = node.each_child_node.select { |node| field_definition?(node) }

          first_field = fields.first
          fields.each_with_index do |node, idx|
            next if node.sibling_index == first_field.sibling_index + idx

            add_offense(node, message: GROUP_DEFS_MSG)
          end
        end

        RESOLVER_AFTER_FIELD_MSG = "Define resolver method after field definition."

        def check_resolver_is_defined_after_definition(node)
          if (kwargs = field_kwargs(node))
            return if kwargs.any? { |kwarg|
              resolver_option?(kwarg) || method_option?(kwarg) || hash_key_option?(kwarg)
            }

            resolver_method = kwargs.flat_map { |kwarg| resolver_method_option(kwarg) }.compact.first
          end

          method_name = resolver_method || field_name(node).first
          method_definition = node.parent.each_child_node.find { |node|
            node.def_type? && node.method_name == method_name
          }

          if method_definition.sibling_index - node.sibling_index > 1
            add_offense(node, message: RESOLVER_AFTER_FIELD_MSG)
          end
        end
      end
    end
  end
end