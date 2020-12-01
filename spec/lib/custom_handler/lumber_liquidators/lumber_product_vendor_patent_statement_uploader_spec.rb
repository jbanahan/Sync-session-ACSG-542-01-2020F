describe OpenChain::CustomHandler::LumberLiquidators::LumberProductVendorPatentStatementUploader do

  # The parent class contains more extensive tests, this is just to make sure everything works together correctly
  describe "process" do
    let (:user) { FactoryBot(:user) }
    let (:custom_file) { instance_double(CustomFile) }
    let (:row_data) {
     [
      ["VENDOR", "PRODUCT", "CODE", "2018-01-01"],
      ["VENDOR", "PRODUCT", "CODE2", "2018-02-01"]
     ]
    }

    let! (:xref_code) { DataCrossReference.create! key: "CODE", value: "TEXT", cross_reference_type: "ll_patent_statement"}
    let! (:xref_code_2) { DataCrossReference.create! key: "CODE2", value: "TEXT2", cross_reference_type: "ll_patent_statement" }
    let (:product) { FactoryBot(:product, unique_identifier: "PRODUCT".rjust(18, '0')) }
    let (:vendor) { FactoryBot(:vendor, system_code: "VENDOR".rjust(10, '0')) }
    let! (:product_vendor_assignment) { product.product_vendor_assignments.create! vendor: vendor }

    subject { described_class.new nil }

    before :each do
      allow(subject).to receive(:custom_file).and_return custom_file
      allow(subject).to receive(:foreach).with(custom_file, skip_headers: true, skip_blank_lines: true).and_yield(row_data[0]).and_yield(row_data[1])
      allow_any_instance_of(ProductVendorAssignment).to receive(:can_edit?).with(user).and_return true
    end

    it "parses file data" do
      subject.process user

      expect(subject.errors).to eq []
      product_vendor_assignment.reload

      email = ActionMailer::Base.deliveries.first
      expect(email).not_to be_nil
      expect(email.to).to eq [user.email]
      expect(email.subject).to eq "Vendor Patent Statement Upload Complete"
      expect(email.body).not_to include "The following errors were encountered"

      expect(product_vendor_assignment.constant_texts.length).to eq 2

      ct = product_vendor_assignment.constant_texts.first
      expect(ct.constant_text).to eq "CODE - TEXT"
      expect(ct.effective_date_start).to eq Date.new(2018, 1, 1)

      ct = product_vendor_assignment.constant_texts.second
      expect(ct.constant_text).to eq "CODE2 - TEXT2"
      expect(ct.effective_date_start).to eq Date.new(2018, 2, 1)

      expect(product_vendor_assignment.entity_snapshots.length).to eq 1
      s = product_vendor_assignment.entity_snapshots.first
      expect(s.context).to eq "Patent Statement Upload"
      expect(s.user).to eq user
    end
  end

  describe "can_view?" do
    let (:ms) { stub_master_setup }
    let (:user) { FactoryBot(:user) }
    let (:group) { Group.use_system_group "PATENTASSIGN" }
    subject { described_class }

    context "LL system" do
      before :each do
        expect(ms).to receive(:custom_feature?).with("Lumber Liquidators").and_return true
      end

      it "allows users in PATENTASSIGN group" do
        user.groups << group
        expect(subject.can_view? user).to eq true
      end

      it "disallows other users" do
        expect(subject.can_view? user).to eq false
      end
    end

    context "non-LL system" do
      before :each do
        expect(ms).to receive(:custom_feature?).with("Lumber Liquidators").and_return false
      end

      it "doesn't allow anyone" do
        user.groups << group
        expect(subject.can_view? user).to eq false
      end
    end

  end
end