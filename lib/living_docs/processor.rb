require 'ffi/clang'
require 'redcarpet'
require 'haml'
require 'tmpdir'
require 'set'
require 'pathname'
require 'erubis'

require 'living_docs/utils'
require 'living_docs/markdown'
require 'living_docs/documentation/function'
require 'living_docs/documentation/struct'
require 'living_docs/code_example'

module LivingDocs
  class Processor
    EXIT_SUCCESS = 0
    EXIT_FAILURE = 1

    def initialize(input_dir, output_dir, options = {})
      @compiler = options[:compiler]
      @cflags = options[:cflags] == "" ? nil : options[:cflags]

      @output_dir = File.absolute_path(output_dir)
      @input_dir = File.absolute_path(input_dir)
      @src_dir = File.join(input_dir, "src")
      @include_dir = File.join(input_dir, "include")
      @project_files = (
        Dir[File.join(@include_dir, "**/*.h")] +
        Dir[File.join(@src_dir, "**/*.c")]
      ).select {|f| File.file?(f)}.to_set

      @documented_functions = {}
      @documented_structs = {}

      @index = FFI::Clang::Index.new
    end

    def process_file(file_path)
      translation_unit = @index.parse_translation_unit(file_path, ["-I#{@include_dir}"])
      cursor = translation_unit.cursor

      unit_functions = {}

      cursor.visit_children do |cursor, parent|
        file_location = cursor.location.file_location
        short_file = Utils.relative_path(file_location.file, @input_dir)

        # Check that function is from a project file and not somewhere else
        # (like stdio.h or something)
        if @project_files.include?(file_location.file)
          if cursor.kind == :cursor_typedef_decl
            # p cursor.spelling
            # p cursor.underlying_type.spelling
          elsif cursor.kind == :cursor_struct
            struct_name = cursor.type.spelling

            if !@documented_structs[short_file] or !@documented_structs[short_file].has_key?(struct_name)
              (@documented_structs[short_file] ||= {})[struct_name] = Documentation::Struct.new(cursor)
            end
          elsif cursor.kind == :cursor_function
            function_name = cursor.spelling

            unit_functions[short_file] ||= []

            # Don't reprocess code we've already parsed
            if @documented_functions[short_file] and @documented_functions[short_file].has_key?(function_name)
              unit_functions[short_file] << @documented_functions[short_file][function_name]
            else
              unit_functions[short_file] << Documentation::Function.new(cursor, short_file)
            end
          end
        end

        # We only care about top-level stuff, no need to recurse
        :continue
      end

      # Merge all documentation for functions with the same name in this
      # translation unit (that is, declarations and definitions)
      merged_function_docs = Hash[
        unit_functions.values.flatten.group_by(&:name).map do |function_name, doc_options|
          [function_name, doc_options.reduce(&:merge)]
        end
      ]

      unit_functions.each do |file, functions|
        @documented_functions[file] ||= {}

        # Use merged docs for each function in this file
        functions.map(&:name).each do |function_name|
          @documented_functions[file][function_name] = merged_function_docs[function_name]
        end
      end
    end

    def run
      FileUtils.makedirs(@output_dir) unless File.directory?(@output_dir)

      Dir[File.join(@src_dir, "**/*.c")].each do |file_path|
        process_file(file_path)
      end

      compile_status = -1

      #tmp_dir = "tmp" ; FileUtils.makedirs(tmp_dir) ; begin
      Dir.mktmpdir("living_docs") do |tmp_dir|
        tmp_include_dir = File.join(tmp_dir, "include")
        tmp_src_dir = File.join(tmp_dir, "src")
        FileUtils.makedirs([tmp_include_dir, tmp_src_dir])

        FileUtils.copy_entry(@include_dir, tmp_include_dir)
        FileUtils.copy_entry(@src_dir, tmp_src_dir)

        FileUtils.cp(Utils.resource_path("living_docs.h"), tmp_include_dir)

        examples_with_function_name = @documented_functions
          .values
          .flat_map {|functions_in_file| functions_in_file.values}
          .flat_map {|fn| Array.new(fn.examples.size, fn.name).zip(fn.examples)}
          .uniq

        example_function_names = []
        example_function_defs = {}

        examples_with_function_name.each_with_index do |(function_name, example), i|
          example_function_name = "__example_#{function_name}_#{i}"
          example_function_names << example_function_name
          example_function_def = [
            "int #{example_function_name}() {",
            example.code,
            "return 0;",
            "}"
          ].join("\n")
          (example_function_defs[example.file] ||= []) << example_function_def
        end

        entry_point_preamble = ""
        example_function_defs.each do |file_name, function_defs|
          if File.extname(file_name) == ".h"
            #FIXME: get include file name in a better way than split/join
            entry_point_preamble << "#include \"#{File.join(*file_name.split('/')[1..-1])}\"\n"
            entry_point_preamble << function_defs.join("\n\n")
          else
            File.open(File.join(tmp_dir, file_name), "a") do |f|
              f.puts '#include "living_docs.h"'
              f.puts function_defs.join("\n\n")
            end
          end
        end

        # Create entry point
        entry_point_code = Utils.render_erb("entry_point.c.erb",
          preamble: entry_point_preamble,
          example_function_names: example_function_names)

        open(File.join(tmp_src_dir, "living_docs_entry_point.c"), "w") do |f|
          f.puts entry_point_code
        end

        # Compile
        command = [
          @compiler,
          @cflags,
          "-o", File.join(@output_dir, "run_examples"),
          "-I", tmp_include_dir,
          "-Wl,-e,__living_docs_entry_point",
          *Dir[File.join(tmp_src_dir, "**/*.c")]].compact
        puts command.join(" ")
        IO.popen(command) {|f| puts f.read}
        compile_status = $?.exitstatus
      end

      return EXIT_FAILURE unless compile_status.zero?

      files = @project_files.map {|file| Utils.relative_path(file, @input_dir)}.sort
      haml = Haml::Engine.new(File.read(Utils.resource_path("index.haml")))

      markdown = Redcarpet::Markdown.new(
        Markdown::HtmlRenderer.new('c'), Markdown::OPTIONS)

      files.each do |file|
        if @documented_functions[file]
          functions = @documented_functions[file].values.sort_by(&:name)
        else
          functions = []
        end

        if @documented_structs[file]
          structs = @documented_structs[file].values.sort_by(&:type_name)
        else
          structs = []
        end

        html = haml.render(Object.new,
          markdown: markdown,
          functions: functions,
          structs: structs,
          current_file: file,
          files: files)

        open(File.join(@output_dir, file.gsub(/\W/, "_") + ".html"), 'w') do |f|
          f.puts(html)
        end
      end

      EXIT_SUCCESS
    end
  end
end
