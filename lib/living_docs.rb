require 'optparse'

require 'living_docs/version'
require 'living_docs/processor'

module LivingDocs
  class << self
    def parse_options(argv)
      options = {
        compiler: "clang",
        cflags: ""
      }

      input_dir = "."

      opts = OptionParser.new do |opts|
        opts.banner = <<-BANNER.gsub(/^ {10}/, "")
          Generate documentation and executable examples for a C project

          livdoc [options] <output_dir>

          Examples:
            Generate docs from code in ./include and ./src, putting the results
            in doc/
            $ livdoc doc/

          Options:
        BANNER

        opts.on("-h", "--help", "Show this help message") {puts opts; exit}
        opts.on("-v", "--version", "Show version") {puts VERSION; exit}
        opts.on("-i", "--input INPUT_DIR", "Input directory") {|c| input_dir = c}
        opts.on("--compiler COMPILER", "Compiler (default=clang)") {|c| options[:compiler] = c}
        opts.on("--cflags CFLAGS", "Compiler flags") {|c| options[:cflags] = c}
      end

      opts.parse!(argv)

      unless argv.size == 1
        puts opts
        exit(1)
      end

      output_dir = argv.last

      [input_dir, output_dir, options]
    end

    def run(argv)
      input_dir, output_dir, options = parse_options(argv)
      Processor.new(input_dir, output_dir, options).run
    end
  end
end
