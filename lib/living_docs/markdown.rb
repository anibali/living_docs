require 'pygments'
require 'redcarpet'

module LivingDocs
  module Markdown
    OPTIONS = {
      nowrap: true,
      autolink: true,
      no_intra_emphasis: true,
      fenced_code_blocks: true,
      lax_html_blocks: true,
      strikethrough: true,
      superscript: true
    }

    class HtmlRenderer < Redcarpet::Render::HTML
      def initialize(default_language=nil)
        super()

        @default_language = default_language
      end

      def block_code(code, language)
        language ||= @default_language

        Pygments.highlight(code, lexer: language)
      end
    end

    class CodeBlockExtractor < Redcarpet::Render::Base
      attr_reader :code_blocks

      def initialize(default_language=nil)
        super()

        @default_language = default_language
        @code_blocks = {}
      end

      def block_code(code, language)
        language ||= @default_language
        (@code_blocks[language] ||= []) << code

        nil
      end
    end
  end
end
