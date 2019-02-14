describe OpenChain::BusinessRulesCopier do
  let(:user) { Factory(:user) }

  context "Uploader" do
    let(:cf) { double "custom file" }
    let(:file) { double "JSON file"}
    let(:uploader) { described_class::Uploader.new cf }
    before do 
      allow(cf).to receive(:path).and_return "/path"
      allow(cf).to receive(:bucket).and_return "bucket"
      allow(cf).to receive(:attached_file_name).and_return "test_json.txt"
      allow(file).to receive(:read).and_return "{\"content\":\"stuff\"}"
    end

    describe "process" do
      it "parses template attributes from JSON file and notifies user" do
        template = OpenStruct.new
        template.name = "temp name"
        expect(OpenChain::S3).to receive(:download_to_tempfile).with("bucket", "/path").and_yield file
        expect(BusinessValidationTemplate).to receive(:parse_copy_attributes).with({"content" => "stuff"}).and_return template
        expect(template).to receive(:update_attributes!).with(name: "temp name", disabled: true)

        uploader.process(user, nil)
        expect(user.messages.count).to eq 1
        msg = user.messages.first
        expect(msg.subject).to eq "File Processing Complete"
        expect(msg.body).to eq "Business Validation Template upload for file test_json.txt is complete."
      end

      it "notifies user of error" do
        expect(OpenChain::S3).to receive(:download_to_tempfile).with("bucket", "/path").and_raise "ERROR!"
        expect(BusinessValidationTemplate).to_not receive(:parse_copy_attributes)
        
        uploader.process(user, nil)
        expect(user.messages.count).to eq 1
        msg = user.messages.first
        expect(msg.subject).to eq "File Processing Complete With Errors"
        expect(msg.body).to eq "Unable to process file test_json.txt due to the following error:<br>ERROR!"
      end
    end
  end

  describe "copy_template" do
    it "copies template" do
      bvt = Factory(:business_validation_template, name: "template")
      expect_any_instance_of(BusinessValidationTemplate).to receive(:copy_attributes).with(include_external: true).and_call_original
      described_class.copy_template user.id, bvt.id
      
      new_bvt = BusinessValidationTemplate.last
      expect(new_bvt.name).to eq "template (COPY)"
      expect(new_bvt.disabled).to eq true
      expect(user.messages.count).to eq 1
      msg = user.messages.first
      expect(msg.subject).to eq "Business Validation Template has been copied."
      expect(msg.body).to eq "Business Validation Template 'template' has been copied."
    end
  end

  describe "copy_rule" do
    it "copies rule to template" do
      bvt = Factory(:business_validation_template)
      bvru = Factory(:business_validation_rule, name: "thys rulez")

      expect_any_instance_of(BusinessValidationRule).to receive(:copy_attributes).with(include_external: true).and_call_original
      described_class.copy_rule user.id, bvru.id, bvt.id
      bvt.reload

      expect(bvt.business_validation_rules.count).to eq 1
      new_rule = bvt.business_validation_rules.first
      expect(new_rule.name).to eq "thys rulez"
      expect(new_rule.disabled).to eq true
      msg = user.messages.first
      expect(msg.subject).to eq "Business Validation Rule has been copied."
      expect(msg.body).to eq "Business Validation Rule 'thys rulez' has been copied."
    end
  end

end
