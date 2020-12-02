describe OpenChain::CustomHandler::Generator315::Abstract315Generator do

  subject do
    Class.new(described_class).new
  end

  # generate_and_send_315s should be tested by including class

  describe "determine_port_code_type" do
    let(:port) { create(:port, schedule_k_code: "12345", schedule_d_code: "4321", unlocode: "UNLOC", iata_code: "ABC", cbsa_port: "2468") }

    it "returns a port's code type given a code" do
      expect(subject.determine_port_code_type("12345", port)).to eq "Schedule K"
      expect(subject.determine_port_code_type("4321", port)).to eq "Schedule D"
      expect(subject.determine_port_code_type("UNLOC", port)).to eq "UNLocode"
      expect(subject.determine_port_code_type("ABC", port)).to eq "IATA"
      expect(subject.determine_port_code_type("2468", port)).to eq "CBSA"
      expect(subject.determine_port_code_type("foo", port)).to be_nil
    end
  end
end
