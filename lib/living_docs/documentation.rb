module LivingDocs
  module Documentation
    class Entity
      attr_accessor :description, :examples
    end

    class Function < Entity
      attr_accessor :name, :parameters, :return_type

      def merge(other)
        # TODO: Make this smarter
        self.description.size > other.description.size ? self : other
      end
    end

    class CodeExample
      attr_reader :file, :code

      def initialize(file, code)
        @file = file
        @code = code
      end
    end
  end
end
