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
end
