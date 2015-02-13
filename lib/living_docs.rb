require 'living_docs/version'
require 'living_docs/processor'

module LivingDocs
  class << self
    def run(argv)
      Processor.new(argv.fetch(0), argv.fetch(1)).run
    end
  end
end
