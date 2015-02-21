require 'living_docs/utils'

module LivingDocs
  module Documentation
    class Entity
      attr_accessor :description, :examples
    end

    class Function < Entity
      attr_accessor :name, :parameters, :return_type

      def initialize(cursor, file)
        raise unless cursor.kind == :cursor_function

        @name = cursor.spelling
        @return_type = cursor.type.result_type.spelling
        @parameters = (0...cursor.num_arguments).map do |i|
          [cursor.type.arg_type(i).spelling,
          cursor.argument(i).spelling].join(" ")
        end

        if cursor.raw_comment_text
          # Use raw comment to avoid clobbering of \n & co due
          # to misinterpretation as documentation commands
          @description = Utils.clean_comment(cursor.raw_comment_text)
          @examples = Utils.extract_code_examples(@description, file)
        else
          @description = ""
          @examples = []
        end
      end

      def merge(other)
        # TODO: Make this smarter
        self.description.size > other.description.size ? self : other
      end
    end
  end
end
