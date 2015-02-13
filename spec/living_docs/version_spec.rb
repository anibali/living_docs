require 'living_docs/version'

describe LivingDocs do
  describe "VERSION" do
    subject { LivingDocs::VERSION }

    it "uses semantic versioning" do
      is_expected.to match(/[0-9A-Za-z\-]+\.[0-9A-Za-z\-]+\.[0-9A-Za-z\-]+/)
    end
  end
end
