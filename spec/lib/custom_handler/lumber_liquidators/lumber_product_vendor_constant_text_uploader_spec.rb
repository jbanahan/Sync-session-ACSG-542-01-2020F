describe OpenChain::CustomHandler::LumberLiquidators::LumberProductVendorConstantTextUploader do

  describe "process", :without_partial_double_verification do
    let (:user) { Factory(:user) }
    let (:custom_file) { instance_double(CustomFile) }
    let (:row_data) {
     [
      ["VENDOR", "PRODUCT", "CODE", "2018-01-01"],
      ["VENDOR", "PRODUCT", "CODE2", "2018-02-01"]
     ]
    }

    let! (:xref_code) { DataCrossReference.create! key: "CODE", value: "TEXT", cross_reference_type: "XREF TYPE"}
    let! (:xref_code_2) { DataCrossReference.create! key: "CODE2", value: "TEXT2", cross_reference_type: "XREF TYPE" }
    let (:product) { Factory(:product, unique_identifier: "PRODUCT".rjust(18, '0')) }
    let (:vendor) { Factory(:vendor, system_code: "VENDOR".rjust(10, '0')) }
    let! (:product_vendor_assignment) { product.product_vendor_assignments.create! vendor: vendor }

    subject { described_class.new nil }

    before :each do
      allow(subject).to receive(:custom_file).and_return custom_file
      allow(subject).to receive(:cross_reference_type).and_return "XREF TYPE"
      allow(subject).to receive(:cross_reference_description).and_return "XREF DESC"
      allow(subject).to receive(:constant_text_type).and_return "TEXT TYPE"
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
      expect(email.subject).to eq "Vendor XREF DESC Upload Complete"
      expect(email.body).not_to include "The following errors were encountered"

      expect(product_vendor_assignment.constant_texts.length).to eq 2

      ct = product_vendor_assignment.constant_texts.first
      expect(ct.text_type).to eq "TEXT TYPE"
      expect(ct.constant_text).to eq "CODE - TEXT"
      expect(ct.effective_date_start).to eq Date.new(2018, 1, 1)

      ct = product_vendor_assignment.constant_texts.second
      expect(ct.text_type).to eq "TEXT TYPE"
      expect(ct.constant_text).to eq "CODE2 - TEXT2"
      expect(ct.effective_date_start).to eq Date.new(2018, 2, 1)

      expect(product_vendor_assignment.entity_snapshots.length).to eq 1
      s = product_vendor_assignment.entity_snapshots.first
      expect(s.context).to eq "XREF DESC Upload"
      expect(s.user).to eq user
    end

    it "skips updating existing constant texts that have the same data" do
      product_vendor_assignment.constant_texts.create! text_type: "TEXT TYPE", constant_text: "CODE - TEXT", effective_date_start: Date.new(2018, 1, 1)
      product_vendor_assignment.constant_texts.create! text_type: "TEXT TYPE", constant_text: "CODE2 - TEXT2", effective_date_start: Date.new(2018, 2, 1)

      subject.process user
      expect(subject.errors).to eq []
      product_vendor_assignment.reload

      expect(product_vendor_assignment.entity_snapshots.length).to eq 0
    end

    it "updates existing texts" do
      # This makes sure the texts are updated based on the code from the file,
      product_vendor_assignment.constant_texts.create! text_type: "TEXT TYPE", constant_text: "CODE - TEXT BLAH", effective_date_start: Date.new(2018, 3, 1)
      product_vendor_assignment.constant_texts.create! text_type: "TEXT TYPE", constant_text: "CODE2 - TEXT2 BLAH", effective_date_start: Date.new(2018, 4, 1)

      subject.process user
      expect(subject.errors).to eq []
      product_vendor_assignment.reload

      expect(product_vendor_assignment.entity_snapshots.length).to eq 1

      expect(product_vendor_assignment.constant_texts.length).to eq 2
      ct = product_vendor_assignment.constant_texts.first
      expect(ct.constant_text).to eq "CODE - TEXT"
      expect(ct.effective_date_start).to eq Date.new(2018, 1, 1)

      ct = product_vendor_assignment.constant_texts.second
      expect(ct.constant_text).to eq "CODE2 - TEXT2"
      expect(ct.effective_date_start).to eq Date.new(2018, 2, 1)
    end

    it "errors if bad cross reference is used" do
      row_data[0][2] = "BAD"

      subject.process user
      expect(subject.errors).to eq ["Error in Row 2: No XREF DESC found for Code 'BAD'."]

      email = ActionMailer::Base.deliveries.first
      expect(email).not_to be_nil
      expect(email.body).to include "Error in Row 2: No XREF DESC found for Code"
    end

    it "errors if vendor assignment is missing" do
      product_vendor_assignment.destroy

      subject.process user
      expect(subject.errors).to eq ["Error in Row 2: Vendor 'VENDOR' is not linked to Product 'PRODUCT'.", "Error in Row 3: Vendor 'VENDOR' is not linked to Product 'PRODUCT'."]
    end

    it "errors if user cannot edit product vendor assignment" do
      expect_any_instance_of(ProductVendorAssignment).to receive(:can_edit?).at_least(1).times.and_return false

      subject.process user
      expect(subject.errors).to eq ["Error in Row 2: You do not have permission to update Vendor 'VENDOR'.", "Error in Row 3: You do not have permission to update Vendor 'VENDOR'."]
    end

    it "handles deletes" do
      row_data[0][4] = "Y"
      # Allow the effective date column to be blank on deletes
      row_data[0][3] = ""
      row_data[1][4] = "Y"

      product_vendor_assignment.constant_texts.create! text_type: "TEXT TYPE", constant_text: "CODE - TEXT BLAH", effective_date_start: Date.new(2018, 3, 1)
      product_vendor_assignment.constant_texts.create! text_type: "TEXT TYPE", constant_text: "CODE2 - TEXT2 BLAH", effective_date_start: Date.new(2018, 4, 1)

      subject.process user
      expect(subject.errors).to eq []
      product_vendor_assignment.reload

      expect(product_vendor_assignment.entity_snapshots.length).to eq 1
      expect(product_vendor_assignment.constant_texts.length).to eq 0
    end

    it "errors if there is an attempt to delete a code that doesn't exist on the the assignment" do
      row_data[0][4] = "Y"
      row_data[1][4] = "Y"

      subject.process user
      expect(subject.errors).to eq [
        "Error in Row 2: Vendor 'VENDOR' / Product 'PRODUCT' does not have a TEXT TYPE code of 'CODE' to delete.",
        "Error in Row 3: Vendor 'VENDOR' / Product 'PRODUCT' does not have a TEXT TYPE code of 'CODE2' to delete.",
      ]

      product_vendor_assignment.reload

      expect(product_vendor_assignment.entity_snapshots.length).to eq 0
    end
  end
end