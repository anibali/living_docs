require 'living_docs/utils'

describe LivingDocs::Utils do
  describe '.relative_path' do
    it 'finds the relative path from one absolute path to another' do
      path = LivingDocs::Utils.relative_path("/foo/bar/baz", "/foo")

      expect(path).to eq("bar/baz")
    end

    it 'is relative to the current working directory by default' do
      Dir.chdir("/usr") do
        path = LivingDocs::Utils.relative_path("/usr/bin/env")

        expect(path).to eq("bin/env")
      end
    end
  end

  describe '.resource_path' do
    it 'returns the correct path to "index.haml"' do
      path = LivingDocs::Utils.resource_path('index.haml')

      expect(File).to exist(path)
    end
  end

  describe '.clean_comment' do
    it 'cleans ///-style comments' do
      comment = "/// This is a comment"
      cleaned_comment = "This is a comment"

      expect(LivingDocs::Utils.clean_comment(comment)).to eq(cleaned_comment)
    end

    it 'cleans /**-style comments' do
      comment = "/**\n * This is a comment\n */"
      cleaned_comment = "This is a comment"

      expect(LivingDocs::Utils.clean_comment(comment)).to eq(cleaned_comment)
    end
  end
end
