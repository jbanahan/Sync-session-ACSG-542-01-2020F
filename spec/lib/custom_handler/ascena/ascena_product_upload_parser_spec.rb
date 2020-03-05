describe OpenChain::CustomHandler::Ascena::AscenaProductUploadParser do

  let (:custom_file) { 
    f = instance_double(CustomFile)
    allow(f).to receive(:attached_file_name).and_return "file.xls"
    f
  }
  subject { described_class.new custom_file }

  describe "can_view?" do
    let (:master_setup) { stub_master_setup }
    let (:master_user) { Factory(:master_user) }
    let (:user) { Factory(:user) }

    context "with ascena parts enabled" do
      before :each do
        allow(master_setup).to receive(:custom_feature?).with("Ascena Parts").and_return true
      end

      it "allows master user who can edit parts access" do
        expect(master_user).to receive(:edit_products?).and_return true
        expect(subject.can_view? master_user).to eq true
      end

      it "disallows users without edit part access" do
        expect(subject.can_view? master_user).to eq false
      end

      it "doesn't allow non-master users" do
        allow(user).to receive(:edit_products?).and_return true
        expect(subject.can_view? user).to eq false
      end
    end

    it "doesn't allow master users when custom feature is not enabled" do
      allow(master_setup).to receive(:custom_feature?).with("Ascena Parts").and_return false
      allow(master_user).to receive(:edit_products?).and_return true
      expect(subject.can_view? master_user).to eq false
    end
  end

  describe "process_file" do
    let (:file_row) do 
      row = ["Brand", "Style", "Garment Type", "ParentID", 300, nil, "Description", nil, "CO", "1234.56.7890"]
      row[33] = "FDA Product Code"
      row[38] = "Customs Description"

      row
    end

    let (:user) { Factory(:user) }
    let! (:ascena) { Factory(:importer, system_code: "ASCENA") }
    let! (:us) { Factory(:country, iso_code: "US") }
    let (:cdefs) { subject.cdefs }

    it "parses a file and creates products" do
      expect(subject).to receive(:foreach).with(custom_file, skip_headers: true).exactly(2).times.and_yield file_row

      subject.process_file custom_file, user

      prod = Product.where(unique_identifier: "ASCENA-Style").first
      expect(prod).not_to be_nil

      expect(prod.name).to eq "Description"
      expect(prod.importer).to eq ascena
      expect_custom_value(prod, cdefs[:prod_brand], "Brand")
      expect_custom_value(prod, cdefs[:prod_part_number], "Style")
      expect_custom_value(prod, cdefs[:prod_reference_number], "ParentID")
      expect_custom_value(prod, cdefs[:prod_department_code], "300")
      expect_custom_value(prod, cdefs[:prod_fda_product_code], "FDA Product Code")
      expect_custom_value(prod, cdefs[:prod_fda_product], true)

      expect(prod.classifications.length).to eq 1
      c = prod.classifications.first
      expect(c.country).to eq us
      expect_custom_value(c, cdefs[:class_customs_description], "Customs Description")

      expect(c.tariff_records.length).to eq 1
      t = c.tariff_records.first
      expect(t.line_number).to eq 1
      expect(t.hts_1).to eq "1234567890"

      # Make sure a snapshot was taken
      expect(prod.entity_snapshots.length).to eq 1
      s = prod.entity_snapshots.first
      expect(s.user).to eq user
      expect(s.context).to eq "file.xls"

      # Should also create a parent part
      prod = Product.where(unique_identifier: "ASCENA-ParentID").first
      expect(prod).not_to be_nil
      expect(prod.name).to eq "Description"
      expect(prod.importer).to eq ascena
      expect_custom_value(prod, cdefs[:prod_part_number], "ParentID")
      expect_custom_value(prod, cdefs[:prod_reference_number], nil)
      expect_custom_value(prod, cdefs[:prod_department_code], "300")

      expect(prod.classifications.length).to eq 1
      c = prod.classifications.first
      expect(c.country).to eq us
      expect_custom_value(c, cdefs[:class_customs_description], "Customs Description")

      expect(c.tariff_records.length).to eq 1
      t = c.tariff_records.first
      expect(t.line_number).to eq 1
      expect(t.hts_1).to eq "1234567890"

      # Make sure a snapshot was taken
      expect(prod.entity_snapshots.length).to eq 1
      s = prod.entity_snapshots.first
      expect(s.user).to eq user
      expect(s.context).to eq "file.xls"
    end

    it "creates Maurices record when brand is 'MAU'" do
      Factory(:importer, system_code: "MAUR")
      file_row[0] = "MAU"

      expect(subject).to receive(:foreach).with(custom_file, skip_headers: true).exactly(2).times.and_yield file_row

      subject.process_file custom_file, user

      prod = Product.where(unique_identifier: "MAUR-Style").first
      expect(prod).not_to be_nil
    end

    it "raises exception if Maurices importer record missing" do
      file_row[0] = "MAU"

      expect(subject).to receive(:foreach).with(custom_file, skip_headers: true).exactly(2).times.and_yield file_row
      expect{ subject.process_file custom_file, user }.to raise_error "Unable to find Maurices company account."
    end

    it "doesn't save or snapshot products that haven't changed any information" do
      # The easiest way to do this is just process the file twice...once using a time that's 
      # in the past, and then the current time and then checking that the product's updated_at 
      # value isn't changed from the previous time.
      allow(subject).to receive(:foreach).with(custom_file, skip_headers: true).and_yield file_row

      yesterday = (Time.zone.now - 1.day)
      Timecop.freeze(yesterday) do
        subject.process_file custom_file, user
      end
      prod = Product.where(unique_identifier: "ASCENA-ParentID").first
      expect(prod.try(:updated_at).to_i).to eq yesterday.to_i

      subject.process_file custom_file, user
      
      prod.reload
      expect(prod.try(:updated_at).to_i).to eq yesterday.to_i

      expect(prod.entity_snapshots.size).to eq 1
    end

    it "updates / snapshots if any data changes" do
      allow(subject).to receive(:foreach).with(custom_file, skip_headers: true).and_yield file_row

      yesterday = (Time.zone.now - 1.day)
      Timecop.freeze(yesterday) do
        subject.process_file custom_file, user
      end
      prod = Product.where(unique_identifier: "ASCENA-ParentID").first
      expect(prod.try(:updated_at).to_i).to eq yesterday.to_i

      file_row[4] = "Update"

      now = Time.zone.now
      Timecop.freeze(now) do
        subject.process_file custom_file, user
      end

      prod.reload
      expect(prod.try(:updated_at).to_i).to eq now.to_i
      expect(prod.entity_snapshots.length).to eq 2
    end

    it "sends a report if any HTS numbers are blanked" do
      user.time_zone = "America/New_York"
      user.email = "test@test.com"
      user.save

      group = MailingList.create!(user: user, company: ascena, name: "Ascena Parts Exceptions", system_code: 'ascena_parts_exceptions')
      group.email_addresses = "#{user.email}"
      group.save
      group.reload

      allow(subject).to receive(:foreach).with(custom_file, skip_headers: true).and_yield(file_row)

      subject.process_file custom_file, user

      no_hts = file_row.dup
      no_hts[9] = nil

      allow(subject).to receive(:foreach).with(custom_file, skip_headers: true).and_yield(no_hts)

      subject.process user

      mail = ActionMailer::Base.deliveries.pop
      expect(mail.to).to include(user.email)
      expect(mail.subject).to include("Ascena Parts Exceptions")
    end

    it "handles duplicate garment types" do
      row_2 = file_row.dup
      row_2[2] = "A Garment Type 2"
      row_2[9] = "1234.56.7800"

      allow(subject).to receive(:foreach).with(custom_file, skip_headers: true).and_yield(file_row).and_yield(row_2)

      subject.process_file custom_file, user

      prod = Product.where(unique_identifier: "ASCENA-Style").first
      expect(prod).not_to be_nil
      expect(prod.classifications.length).to eq 1
      c = prod.classifications.first
      expect(c.country).to eq us
      expect_custom_value(c, cdefs[:class_customs_description], "Customs Description")

      # Subsequent run
      # We are giving the parser the same rows twice to duplicate a bug that was brought up in ticket 26648
      allow(subject).to receive(:foreach).with(custom_file, skip_headers: true).and_yield(file_row).and_yield(row_2).and_yield(file_row).and_yield(row_2)

      subject.process_file custom_file, user

      prod = Product.where(unique_identifier: "ASCENA-Style").first
      expect(prod).not_to be_nil
      expect(prod.classifications.length).to eq 1
      c = prod.classifications.first
      expect(c.country).to eq us
      expect_custom_value(c, cdefs[:class_customs_description], "Customs Description")
      expect_custom_value(c, cdefs[:class_classification_notes], "A Garment Type 2: 1234.56.7800\n Garment Type: 1234.56.7890")
    end

    it "handles same styles with different garment types in the file" do
      row_2 = file_row.dup
      row_2[2] = "A Garment Type 2"
      row_2[9] = "1234.56.7800"

      allow(subject).to receive(:foreach).with(custom_file, skip_headers: true).and_yield(file_row).and_yield(row_2)

      subject.process_file custom_file, user

      # The big difference here is that a single product should get made, but it shouldn't have a classification and it should 
      # show garment types and their HTS in the Classification Notes field.

      prod = Product.where(unique_identifier: "ASCENA-Style").first
      expect(prod).not_to be_nil
      expect(prod.classifications.length).to eq 1
      c = prod.classifications.first
      expect(c.country).to eq us
      expect_custom_value(c, cdefs[:class_customs_description], "Customs Description")
      expect_custom_value(c, cdefs[:class_classification_notes], "A Garment Type 2: 1234.56.7800\n Garment Type: 1234.56.7890")

      expect(c.tariff_records.first).to be_nil
    end

    it "handles files w/ blank parent ids" do
      allow(subject).to receive(:foreach).with(custom_file, skip_headers: true).exactly(2).times.and_yield file_row

      file_row[3] = nil

      subject.process_file custom_file, user

      prod = Product.where(unique_identifier: "ASCENA-Style").first
      expect(prod).not_to be_nil

      # Should not create a blank parent part
      prod = Product.where(unique_identifier: "ASCENA-").first
      expect(prod).to be_nil
    end
  end

  describe "assign_fda" do
    let(:cdefs) { subject.cdefs }
    let(:prod)  { Factory(:product) }
    let(:changed) { MutableBoolean.new(false) }

    it "sets FDA Product Code, FDA Product? when there's a value" do
      subject.assign_fda prod, cdefs[:prod_fda_product_code], cdefs[:prod_fda_product], "FDA CODE", changed
      expect_custom_value(prod, cdefs[:prod_fda_product_code], "FDA CODE")
      expect_custom_value(prod, cdefs[:prod_fda_product], true)
      expect(changed.value).to eq true
    end

    it "sets FDA Product Code, FDA Product? when value is blank" do
      prod.update_custom_value!(cdefs[:prod_fda_product_code], "foo")
      prod.update_custom_value!(cdefs[:prod_fda_product], true)
      subject.assign_fda prod, cdefs[:prod_fda_product_code], cdefs[:prod_fda_product], "", changed
      
      expect_custom_value(prod, cdefs[:prod_fda_product_code], nil)
      expect_custom_value(prod, cdefs[:prod_fda_product], nil)
      expect(changed.value).to eq true
    end
  end

  describe "process" do
    let (:user) { Factory(:user) }

    it "processes a file" do
      expect(subject).to receive(:process_file).with custom_file, user
      subject.process user

      m = user.messages.first
      expect(m).not_to be_nil
      expect(m.subject).to eq "File Processing Complete"
      expect(m.body).to eq "Ascena Product Upload processing for file file.xls is complete."
    end

    it "handles error" do
      expect(subject).to receive(:process_file).and_raise "Error"
      subject.process user

      m = user.messages.first
      expect(m).not_to be_nil
      expect(m.subject).to eq "File Processing Complete With Errors"
      expect(m.body).to eq "Unable to process file file.xls due to the following error:<br>Error"
    end
  end
end
