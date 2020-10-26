describe IntacctPayable do
  subject { described_class }

  describe "suggested_fix" do
    it "recognizes Payable missing vendor errors" do
      expect(subject.suggested_fix("Description 2: Invalid Vendor")).to eq "Create Vendor account in Intacct and/or ensure account has payment Terms set."
    end

    it "recognizes Payable missing vendor errors with bad vendor object" do
      expect(subject.suggested_fix("Failed to find vendor object with key SSA.")).to eq "Create Vendor account in Intacct and/or ensure account has payment Terms set."
    end

    it "recognizes Payable missing vendor terms errors" do
      expect(subject.suggested_fix("Failed to retrieve Terms for Vendor")).to eq "Create Vendor account in Intacct and/or ensure account has payment Terms set."
    end

    it "recognizes Payable invalid customer errors" do
      expect(subject.suggested_fix("Description 2: Invalid Customer")).to eq "Create Customer account in Intacct."
    end

    it "recognizes Payable retry errors" do
      expect(subject.suggested_fix("BL01001973 XL03000009")).to eq "Temporary Upload Error. Click 'Clear This Error' link to try again."
    end

    it "recognizes Cloudflare errors" do
      expect(subject.suggested_fix("Missing end tag for 'meta' (got \"head\")
Line: 22
Position: 1066
Last 80 unconsumed characters:
")).to eq "Temporary Upload Error. Click 'Clear This Error' link to try again."
    end
  end
end
