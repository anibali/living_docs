require 'living_docs/utils'
require 'living_docs/documentation/entity'

module LivingDocs
  module Documentation
    class Struct < Entity
      attr_reader :name, :type_name, :fields

      def initialize(cursor)
        raise unless cursor.kind == :cursor_struct

        @examples = []

        if cursor.raw_comment_text
          @description = Utils.clean_comment(cursor.raw_comment_text)
        else
          @description = ""
        end

        @name = cursor.spelling
        @type_name = cursor.type.spelling

        @fields = []
        cursor.visit_children do |child|
          # FIXME: Unnamed nested structs & unions
          if child.kind == :cursor_field_decl
            @fields << [child.type.spelling, child.spelling].join(" ")
          end

          :continue
        end
      end

      def anonymous?
        @name.empty?
      end
    end
  end
end
