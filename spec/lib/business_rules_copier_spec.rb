describe OpenChain::BusinessRulesCopier do
  let(:user) { FactoryBot(:user) }

  context "TemplateUploader" do
    let(:cf) { double "custom file" }
    let(:file) { double "JSON file"}
    let(:template_uploader) { described_class::TemplateUploader.new cf }
    before do
      allow(cf).to receive(:path).and_return "/path"
      allow(cf).to receive(:bucket).and_return "bucket"
      allow(cf).to receive(:attached_file_name).and_return "test_json.txt"
      allow(file).to receive(:read).and_return "{\"content\":\"stuff\"}"
    end

    describe "process" do
      it "parses template attributes from JSON file and notifies user" do
        template = BusinessValidationTemplate.new name: "temp name"
        expect(OpenChain::S3).to receive(:download_to_tempfile).with("bucket", "/path").and_yield file
        expect(BusinessValidationTemplate).to receive(:parse_copy_attributes).with({"content" => "stuff"}).and_return template
        expect(template).to receive(:update_attributes!).with(name: "temp name", disabled: true)

        template_uploader.process(user, nil)
        expect(user.messages.count).to eq 1
        msg = user.messages.first
        expect(msg.subject).to eq "File Processing Complete"
        expect(msg.body).to eq "Business Validation Template upload for file test_json.txt is complete."
      end

      it "notifies user of error" do
        expect(OpenChain::S3).to receive(:download_to_tempfile).with("bucket", "/path").and_raise "ERROR!"
        expect(BusinessValidationTemplate).to_not receive(:parse_copy_attributes)

        template_uploader.process(user, nil)
        expect(user.messages.count).to eq 1
        msg = user.messages.first
        expect(msg.subject).to eq "File Processing Complete With Errors"
        expect(msg.body).to eq "Unable to process file test_json.txt due to the following error:<br>ERROR!"
      end
    end
  end

  context "RuleUploader" do
    let(:cf) { double "custom file" }
    let(:file) { double "JSON file"}
    let(:rule_uploader) { described_class::RuleUploader.new cf }
    let!(:bvt) { FactoryBot(:business_validation_template) }
    before do
      allow(cf).to receive(:path).and_return "/path"
      allow(cf).to receive(:bucket).and_return "bucket"
      allow(cf).to receive(:attached_file_name).and_return "test_json.txt"
      allow(file).to receive(:read).and_return "{\"content\":\"stuff\"}"
    end

    describe "process" do
      it "parses rule attributes from JSON file and notifies user" do
        rule = instance_double(BusinessValidationRule)
        allow(rule).to receive(:name).and_return "temp name"

        bvr_relation = double("bvr relation")
        expect(OpenChain::S3).to receive(:download_to_tempfile).with("bucket", "/path").and_yield file
        expect(BusinessValidationRule).to receive(:parse_copy_attributes).with({"content" => "stuff"}).and_return rule
        expect(rule).to receive(:update_attributes!).with(name: "temp name", disabled: true)
        expect_any_instance_of(BusinessValidationTemplate).to receive(:business_validation_rules).and_return bvr_relation
        expect(bvr_relation).to receive(:<<).with rule

        rule_uploader.process(user, bvt_id: bvt.id)
        expect(user.messages.count).to eq 1
        msg = user.messages.first
        expect(msg.subject).to eq "File Processing Complete"
        expect(msg.body).to eq "Business Validation Rule upload for file test_json.txt is complete."
      end

      it "notifies user of error" do
        expect(OpenChain::S3).to receive(:download_to_tempfile).with("bucket", "/path").and_raise "ERROR!"
        expect(BusinessValidationRule).to_not receive(:parse_copy_attributes)

        rule_uploader.process(user, nil)
        expect(user.messages.count).to eq 1
        msg = user.messages.first
        expect(msg.subject).to eq "File Processing Complete With Errors"
        expect(msg.body).to eq "Unable to process file test_json.txt due to the following error:<br>ERROR!"
      end
    end
  end

  describe "copy_template" do
    it "copies template" do
      bvt = FactoryBot(:business_validation_template, name: "template")
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
      bvt = FactoryBot(:business_validation_template)
      bvru = FactoryBot(:business_validation_rule, name: "thys rulez")

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
