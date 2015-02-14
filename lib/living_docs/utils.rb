require 'pathname'

module LivingDocs
  RESOURCE_DIR = File.expand_path("../../../res", __FILE__).freeze

  module UtilMethods
    def resource_path(*resource_name)
      File.join(RESOURCE_DIR, *resource_name)
    end

    def relative_path(path, relative_to=Dir.pwd)
      dest_path = Pathname.new(File.absolute_path(path))
      src_path = Pathname.new(File.absolute_path(relative_to))
      dest_path.relative_path_from(src_path).to_s
    end

    def unindent_text(text)
      lines = text.split("\n")
      return "" if lines.empty?

      if lines.length > 1
        indentation = lines.reject(&:empty?).reduce do |a, b|
          indentation_a = a.match(/\s*/).to_s
          indentation_b = b.match(/\s*/).to_s
          common_prefix = ""
          indentation_a.chars.each_with_index do |s, i|
            common_prefix << s if s == indentation_b[i]
          end
          common_prefix
        end
      else
        indentation = lines.first.match(/\s*/).to_s
      end

      lines.map {|l| l[indentation.size..-1] || ""}.join("\n")
    end

    def clean_comment(comment_text)
      if comment_text.start_with? "/*"
        unindent_text(comment_text.split("\n")[1..-2].map do |line|
          line.sub(/^\s*\*/, '')
        end.join("\n"))
      elsif comment_text.start_with? "///"
        unindent_text(comment_text.gsub(/^\/\/\//, ''))
      else
        nil
      end
    end

    def render_erb(resource_name, binding={})
      erb_template = File.read(resource_path(resource_name))
      Erubis::Eruby.new(erb_template).result(binding)
    end
  end

  module Utils
    class << self
      include UtilMethods
    end
  end
end
