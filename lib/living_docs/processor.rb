require 'ffi/clang'
require 'redcarpet'
require 'haml'
require 'tmpdir'
require 'set'
require 'pathname'
require 'erubis'

require 'living_docs/utils'
require 'living_docs/markdown'

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

      @example_code = {}
      @documentation = {}
      @seen = Set.new

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

      cursor.visit_children do |cursor, parent|
        file_location = cursor.location.file_location
        short_file = Utils.relative_path(file_location.file, @input_dir)

        # Check that function is from a project file and not somewhere else
        # (like stdio.h or something)
        if @project_files.include?(file_location.file)
          if cursor.kind == :cursor_function
            # Skip code locations we have already visited
            location_string = "#{file_location.file}:#{file_location.offset}"
            next :recurse if @seen.include?(location_string)
            @seen << location_string

            function_name = cursor.spelling
            return_type = cursor.type.result_type.spelling
            parameters = (0...cursor.num_arguments).map do |i|
              [cursor.type.arg_type(i).spelling,
              cursor.argument(i).spelling].join(" ")
            end
            description = ""

            if cursor.raw_comment_text
              # Use raw comment to avoid clobbering of \n & co due
              # to misinterpretation as documentation commands
              comment_text = Utils.clean_comment(cursor.raw_comment_text)

              description = @markdown.render(comment_text)

              function_examples = []
              extract_code_blocks(comment_text).each_with_index do |example, i|
                function_examples << example.split("\n").map(&:strip).join("\n")
              end

              @example_code[function_name] = {
                file: short_file,
                examples: function_examples
              }
            end

            # TODO: Handle conflicts (eg declaration vs definition)

            (@documentation[short_file] ||= []) << {
              function: {
                name: function_name,
                parameters: parameters,
                return_type: return_type
              },
              description: description
            }
          end
        end

        :recurse
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

        appended_code = {}
        @example_code.each do |function_name, info|
          info.fetch(:examples).each_with_index do |example_code, i|
            example_function_name = "__example_#{function_name}_#{i}"
            example_function_names << example_function_name
            function_defs = appended_code[info.fetch(:file)] || []
            function_defs << [
              "int #{example_function_name}() {",
              example_code,
              "return 0;",
              "}"
            ].join("\n")
            appended_code[info.fetch(:file)] = function_defs
          end
        end

        entry_point_preamble = ""
        appended_code.each do |file_name, function_defs|
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
        documentation = @documentation[file] || []
        html = haml.render(Object.new,
          documentation: documentation.sort_by {|h| h.fetch(:function).fetch(:name)},
          current_file: file,
          files: files)
        open(File.join(@output_dir, file.gsub(/\W/, "_") + ".html"), 'w') {|f| f.puts(html) }
      end

      # Successful exit code
      0
    end
  end
end
