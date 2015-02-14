require 'ffi/clang'
require 'redcarpet'
require 'haml'
require 'tmpdir'
require 'set'
require 'pathname'
require 'erubis'

require 'living_docs/utils'
require 'living_docs/markdown'
require 'living_docs/documentation'

module LivingDocs
  class Processor
    def initialize(input_dir, output_dir)
      @output_dir = File.absolute_path(output_dir)
      @input_dir = File.absolute_path(input_dir)
      @src_dir = File.join(input_dir, "src")
      @include_dir = File.join(input_dir, "include")
      @project_files = (
        Dir[File.join(@include_dir, "**/*.h")] +
        Dir[File.join(@src_dir, "**/*.c")]
      ).select {|f| File.file?(f)}.to_set

      @documented_functions = {}

      @index = FFI::Clang::Index.new

      @renderer = Markdown::HtmlRenderer.new('c')
      @markdown_options = {
        nowrap: true,
        autolink: true,
        no_intra_emphasis: true,
        fenced_code_blocks: true,
        lax_html_blocks: true,
        strikethrough: true,
        superscript: true
      }
      @markdown = Redcarpet::Markdown.new(@renderer, @markdown_options)
    end

    def extract_code_blocks(markdown_text)
      code_extractor = Markdown::CodeBlockExtractor.new('c')
      Redcarpet::Markdown.new(code_extractor, @markdown_options).render(markdown_text)
      code_extractor.code_blocks['c'] || []
    end

    def process_file(file_path)
      translation_unit = @index.parse_translation_unit(file_path, ["-I#{@include_dir}"])
      cursor = translation_unit.cursor

      unit_functions = {}
      unit_file_functions = {}

      cursor.visit_children do |cursor, parent|
        file_location = cursor.location.file_location
        short_file = Utils.relative_path(file_location.file, @input_dir)

        # Check that function is from a project file and not somewhere else
        # (like stdio.h or something)
        if @project_files.include?(file_location.file)
          if cursor.kind == :cursor_function
            function_name = cursor.spelling

            unit_functions[function_name] ||= []
            (unit_file_functions[short_file] ||= Set.new) << function_name

            # Don't reprocess code we've already parsed
            if @documented_functions[short_file] and @documented_functions[short_file].has_key?(function_name)
              unit_functions[function_name] << @documented_functions.fetch(short_file).fetch(function_name)
              next :recurse
            end

            return_type = cursor.type.result_type.spelling
            parameters = (0...cursor.num_arguments).map do |i|
              [cursor.type.arg_type(i).spelling,
              cursor.argument(i).spelling].join(" ")
            end
            description = ""
            examples = []

            if cursor.raw_comment_text
              # Use raw comment to avoid clobbering of \n & co due
              # to misinterpretation as documentation commands
              comment_text = Utils.clean_comment(cursor.raw_comment_text)

              description = @markdown.render(comment_text)

              extract_code_blocks(comment_text).each_with_index do |example, i|
                code = example.split("\n").map(&:strip).join("\n")
                examples << Documentation::CodeExample.new(short_file, code)
              end
            end

            function = Documentation::Function.new
            function.name = function_name
            function.parameters = parameters
            function.return_type = return_type
            function.description = description
            function.examples = examples

            unit_functions[function_name] << function
          end
        end

        :recurse
      end

      merged_function_docs = Hash[unit_functions.map do |function_name, doc_options|
        [function_name, doc_options.reduce(&:merge)]
      end]

      unit_file_functions.each do |file, functions|
        @documented_functions[file] ||= {}

        functions.each do |function_name|
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

        example_function_names = []
        example_function_defs = {}

        examples_with_function_name = @documented_functions
          .flat_map {|k, v| v.values.flat_map {|fn| fn.examples.map {|example| [fn.name, example]}}}
          .uniq
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
          "clang",
          *Dir[File.join(tmp_src_dir, "**/*.c")],
          "-o", File.join(@output_dir, "run_examples"),
          "-I", tmp_include_dir,
          "-Wl,-e,__living_docs_entry_point"]
        puts command.join(" ")
        IO.popen(command) {|f| puts f.read}
        compile_status = $?.exitstatus
      end

      return 1 unless compile_status.zero?

      files = @project_files.map {|file| Utils.relative_path(file, @input_dir)}.sort
      haml = Haml::Engine.new(File.read(Utils.resource_path("index.haml")))

      files.each do |file|
        if @documented_functions[file]
          functions = @documented_functions[file].values.sort_by(&:name)
        else
          functions = []
        end
        html = haml.render(Object.new,
          functions: functions,
          current_file: file,
          files: files)
        open(File.join(@output_dir, file.gsub(/\W/, "_") + ".html"), 'w') {|f| f.puts(html) }
      end

      # Successful exit code
      0
    end
  end
end
