describe RandomAudit do
  let!(:u) { create(:user) }
  let!(:ra) { create(:random_audit, user: u) }

  describe "can_view?" do

    it "returns true if user matches associated" do
      expect(ra.can_view? u).to eq true
    end

    it "returns false otherwise" do
      expect(ra.can_view? create(:user)).to eq false
    end
  end

  describe "secure_url" do
    it "calls S3" do
      Tempfile.open(["file", ".txt"]) do |t|
        ra.update_attributes! attached: t
        expect(OpenChain::S3).to receive(:url_for).with("chain-io", ra.attached.path, 10.seconds, :response_content_disposition=>%Q(attachment; filename="#{ra.attached_file_name}"))
        ra.secure_url
      end
    end
  end

end
