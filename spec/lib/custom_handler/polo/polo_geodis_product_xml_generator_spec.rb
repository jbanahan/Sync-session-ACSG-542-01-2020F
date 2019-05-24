describe OpenChain::CustomHandler::Polo::PoloGeodisProductXmlGenerator do

  describe "sync_code" do
    it "uses correct sync code" do
      expect(subject.sync_code).to eq "geodis"
    end
  end

  describe "ftp_credentials" do
   let (:master_setup) { stub_master_setup }
    it "uses correct production credentials" do
      expect(master_setup).to receive(:production?).and_return true
      credentials = subject.ftp_credentials

      expect(credentials[:folder]).to eq "to_ecs/rl_geodis_product"
    end

    it "uses correct non-production credentials" do
      expect(master_setup).to receive(:production?).and_return false
      credentials = subject.ftp_credentials

      expect(credentials[:folder]).to eq "to_ecs/rl_geodis_product_test"
    end
  end
end