describe OpenChain::EmailValidationSupport do
  subject { Class.new { include OpenChain::EmailValidationSupport }.new }

  describe "email_list_valid?" do
    context "with string" do
      it "returns true if every email in a comma/semi-colon separated string is valid" do
        expect(subject.email_list_valid?("tufnel@stonehenge.biz, st-hubbins@hellhole.co.uk; smalls@sharksandwich.net")).to eq true
      end

      it "returns false if any are invalid" do
        expect(subject.email_list_valid?("tufnel@stonehenge.biz, st-hubbins@hellhole.co.uk; smalls@shark!sandwich.net")).to eq false
      end

      it "returns false for blank input" do
        expect(subject.email_list_valid?("")).to eq false
      end

      it "returns false for spaces not adjacent to a comma" do
        expect(subject.email_list_valid?("tufnel@stonehenge.biz, st-hubbins@hellhole.co. uk")).to eq false
      end

      it "returns false if newlines are present" do
        expect(subject.email_list_valid?("tufnel@stonehenge.biz,\nst-hubbins@hellhole.co.uk")).to eq false
      end

      it "allows handling newlines" do
        expect(subject.email_list_valid?("tufnel@stonehenge.biz,\nst-hubbins@hellhole.co.uk", allow_newlines: true)).to eq false
      end
    end

    context "with array" do
      it "returns true if every email in an array is valid" do
        expect(subject.email_list_valid?(["tufnel@stonehenge.biz", "st-hubbins@hellhole.co.uk", "smalls@sharksandwich.net"])).to eq true
      end

      it "returns false if any are invalid" do
        expect(subject.email_list_valid?(["tufnel@stonehenge.biz", "st-hubbins@hellhole.co.uk", "smalls@shark!sandwich.net"])).to eq false
      end

      it "returns false for blank input" do
        expect(subject.email_list_valid?([])).to eq false
      end

      it "allows handling newlines" do
        expect(subject.email_list_valid?(["tufnel@stonehenge.biz", "st-hubbins@hellhole.co.uk\nsmalls@shark!sandwich.net"], allow_newlines: true)).to eq false
      end
    end
  end

  describe "partition_valid_email_addresses" do
    # I'm not going to go through every valid / invalid case here..that's already really checked above
    context "with string" do
      it "returns arrays of valid and invalid emails" do
        valid, invalid = subject.partition_valid_email_addresses("tufnel@stonehenge.biz, tufnel; st-hubbins@hellhole.co.uk\nsmalls@shark!sandwich.net")
        expect(valid).to eq ["tufnel@stonehenge.biz", "st-hubbins@hellhole.co.uk"]
        expect(invalid).to eq ["tufnel", "smalls@shark!sandwich.net"]
      end
    end

    context "with array" do
      it "returns arrays of valid and invalid emails" do
        valid, invalid = subject.partition_valid_email_addresses(["tufnel@stonehenge.biz", "tufnel; st-hubbins@hellhole.co.uk\nsmalls@shark!sandwich.net"])
        expect(valid).to eq ["tufnel@stonehenge.biz", "st-hubbins@hellhole.co.uk"]
        expect(invalid).to eq ["tufnel", "smalls@shark!sandwich.net"]
      end
    end
  end

  describe "email_valid?" do
    # this method calls through to a gem, so we're only going to do some minimal checks here
    it "validates a single email address" do
      expect(subject.email_valid?("tufnel@stonehenge.biz")).to eq true
    end

    it "invalidates a single email address" do
      expect(subject.email_valid?("smalls@shark!sandwich.net")).to eq false
    end

    it "fails addresses with newlines" do
      # The gem we're using for some reason doesn't reject on newlines
      expect(subject.email_valid?("tufnel@stonehenge.biz\n")).to eq false
    end
  end

  describe "split_email_list" do
    it "splits email strings into distinct addresses" do
      expect(subject.split_email_list("tufnel@stonehenge.biz, st-hubbins@hellhole.co.uk; smalls@sharksandwich.net\n me@there.com   "))
        .to eq ["tufnel@stonehenge.biz", "st-hubbins@hellhole.co.uk", "smalls@sharksandwich.net", "me@there.com"]
    end

    it "does not split on newlines if instructed" do
      expect(subject.split_email_list("tufnel@stonehenge.biz, st-hubbins@hellhole.co.uk; smalls@sharksandwich.net\n me@there.com   ", allow_newlines: false))
        .to eq ["tufnel@stonehenge.biz", "st-hubbins@hellhole.co.uk", "smalls@sharksandwich.net\nme@there.com"]
    end
  end
end
