describe OpenChain::Report::ReportEmailHelper do

  subject { Class.new { include OpenChain::Report::ReportEmailHelper }.new }

  describe "parse_email_from_opts" do
    let (:full_opts) do
      {
        "email" => "me@there.com",
        "email_group" => "group",
        "cc" => "you@there.com",
        "bcc" => "her@there.com"
      }
    end

    it "parses email addresses and groups from opts" do
      group = MailingList.create! system_code: "group", name: "Test Email Group", user: FactoryBot(:user), company: FactoryBot(:company)
      expect(subject.parse_email_from_opts(full_opts)).to eq({
                                                               to: ["me@there.com", group],
                                                               cc: ["you@there.com"],
                                                               bcc: ["her@there.com"]
                                                             })
    end

    it "errors if a given email address is invalid" do
      expect { subject.parse_email_from_opts({"email" => "me"}) }.to raise_error ArgumentError, "Invalid email address found: me."
    end

    it "errors if a given email address has multiple invalid emails" do
      expect { subject.parse_email_from_opts({"email" => "me, you"}) }.to raise_error ArgumentError, "Invalid email addresses found: me, you."
    end

    it "errors if given group is missing" do
      expect { subject.parse_email_from_opts({"email_group" => "group"}) }.to raise_error ArgumentError, "Invalid email group found: group."
    end

    it "errors if no to email addresses are found" do
      expect { subject.parse_email_from_opts({"cc" => "me@there.com"}) }.to raise_error ArgumentError, "At least one email address must be present under the 'email' key."
    end

    it "allows using alternate opts key values" do
      group = MailingList.create! system_code: "group", name: "Test Email Group", user: FactoryBot(:user), company: FactoryBot(:company)
      opts = {"x_to" => "me@there.com", "x_group" => "group", "x_cc" => "you@there.com", "x_bcc" => "we@there.com" }
      fields = { to_param: "x_to", group_param: "x_group", cc_param: "x_cc", bcc_param: "x_bcc" }

      expect(subject.parse_email_from_opts(opts, **fields)).to eq({
                                                                    to: ["me@there.com", group],
                                                                    cc: ["you@there.com"],
                                                                    bcc: ["we@there.com"]
                                                                  })
    end
  end

  describe "parse_email_list" do
    it "parses an email list to an array" do
      expect(subject.parse_email_list("me@there.com; you@there.com, he@there.com\n she@there.com")).to eq ["me@there.com", "you@there.com", "he@there.com", "she@there.com"]
    end

    it "errors if any email in the list is invalid" do
      expect { subject.parse_email_list("me@there; you@there") }.to raise_error ArgumentError, "Invalid email addresses found: me@there, you@there."
    end

    it "returns nil if no email is present" do
      expect(subject.parse_email_list("")).to be_nil
    end
  end

  describe "parse_email_group" do
    let (:company) { FactoryBot(:company) }
    let (:user) { FactoryBot(:user) }
    let (:mailing_list) { MailingList.create! system_code: "group", name: "Test Email Group", user: user, company: company}

    it "validates an email group" do
      mailing_list
      expect(subject.parse_email_group("group")).to eq [mailing_list]
    end

    it "returns multiple groups" do
      mailing_list
      groupa = MailingList.create! system_code: "groupa", name: "Test Email Group 2", user: user, company: company
      expect(subject.parse_email_group(["group", "groupa"])).to eq [mailing_list, groupa]
    end

    it "errors if email group is not present" do
      expect { subject.parse_email_group(["group", "groupa"]) }.to raise_error ArgumentError, "Invalid email group found: group, groupa."
    end

    it "returns nil if no code given" do
      expect(subject.parse_email_group("")).to be_nil
    end
  end
end