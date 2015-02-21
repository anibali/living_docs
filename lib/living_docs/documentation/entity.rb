module LivingDocs
  module Documentation
    class Entity
      attr_reader :description, :examples

      def merge(other)
        # TODO: Make this smarter
        self.description.size > other.description.size ? self : other
      end
    end
  end
end
