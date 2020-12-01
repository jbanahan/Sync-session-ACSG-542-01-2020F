describe OpenChain::CustomHandler::PoloCsmSyncHandler do

  before :all do
    described_class.new(nil).send(:cdefs)
  end

  after :all do
    CustomDefinition.destroy_all
  end


  describe "process" do

    let (:cdefs) { @h.send(:cdefs) }

    before :each do
      @xlc = double('xl_client')
      allow(@xlc).to receive(:raise_errors=)
      @cf = double('custom_file')
      @att = double('attached')
      expect(@att).to receive(:path).and_return('/path/to')
      allow(@cf).to receive(:attached).and_return(@att)
      allow(@cf).to receive(:update_attributes)
      expect(OpenChain::XLClient).to receive(:new).with('/path/to').and_return(@xlc)
      @h = described_class.new @cf
      allow_any_instance_of(Product).to receive(:can_edit?).and_return(true)
      @snapshot_created = false
      @snapshot_user
      allow_any_instance_of(Product).to receive(:create_snapshot) do |instance, user|
        @snapshot_user = user
        @snapshot_created = true
      end
    end

    context "csm_season" do

      it "should set CSM Season for existing products" do
        p = FactoryBot(:product)
        p.update_custom_value! cdefs[:csm_season], 'someval'
        expect(@xlc).to receive(:last_row_number).and_return(1)
        expect(@xlc).to receive(:get_row_as_column_hash).with(0, 1).and_return(
          0=>{'value'=>'seas', 'datatype'=>'string'},
          2=>{'value'=>'140', 'datatype'=>'string'},
          3=>{'value'=>'ABCDE', 'datatype'=>'string'},
          4=>{'value'=>'FGHIJ', 'datatype'=>'string'},
          5=>{'value'=>'KLMNO', 'datatype'=>'string'},
          8=>{'value'=>p.unique_identifier, 'datatype'=>'string'},
          13=>{'value'=>'CSMDEPT', 'datatype'=>'string'}
        )
        u = FactoryBot(:user)
        @h.process u
        p.reload
        expect(p.custom_value(cdefs[:csm_season])).to eq("seas\nsomeval")
        expect(@snapshot_created).to be_truthy
        expect(@snapshot_user).to eq u
      end

      it "should set CSM Season for new product" do
        expect(@xlc).to receive(:last_row_number).and_return(1)
        expect(@xlc).to receive(:get_row_as_column_hash).with(0, 1).and_return(
          0=>{'value'=>'seas', 'datatype'=>'string'},
          2=>{'value'=>'140', 'datatype'=>'string'},
          3=>{'value'=>'ABCDE', 'datatype'=>'string'},
          4=>{'value'=>'FGHIJ', 'datatype'=>'string'},
          5=>{'value'=>'KLMNO', 'datatype'=>'string'},
          8=>{'value'=>'newproduid', 'datatype'=>'string'},
          13=>{'value'=>'CSMDEPT', 'datatype'=>'string'}
        )
        @h.process FactoryBot(:user)
        p = Product.find_by unique_identifier: 'newproduid'
        expect(p.custom_value(cdefs[:csm_season])).to eq('seas')
      end

      it "should accumulate CSM Seasons" do
        p = FactoryBot(:product)
        expect(@xlc).to receive(:last_row_number).and_return(2)
        expect(@xlc).to receive(:get_row_as_column_hash).with(0, 1).and_return(
          0=>{'value'=>'seas', 'datatype'=>'string'},
          2=>{'value'=>'140', 'datatype'=>'string'},
          3=>{'value'=>'ABCDE', 'datatype'=>'string'},
          4=>{'value'=>'FGHIJ', 'datatype'=>'string'},
          5=>{'value'=>'KLMNO', 'datatype'=>'string'},
          8=>{'value'=>p.unique_identifier, 'datatype'=>'string'},
          13=>{'value'=>'CSMDEPT', 'datatype'=>'string'}
        )
        expect(@xlc).to receive(:get_row_as_column_hash).with(0, 2).and_return(
          0=>{'value'=>'aaa', 'datatype'=>'string'},
          2=>{'value'=>'140', 'datatype'=>'string'},
          3=>{'value'=>'ABCDE', 'datatype'=>'string'},
          4=>{'value'=>'FGHIJ', 'datatype'=>'string'},
          5=>{'value'=>'KLMNO', 'datatype'=>'string'},
          8=>{'value'=>p.unique_identifier, 'datatype'=>'string'},
          13=>{'value'=>'CSMDEPT', 'datatype'=>'string'}
        )
        @h.process FactoryBot(:user)
        expect(p.custom_value(cdefs[:csm_season])).to eq("aaa\nseas")
      end
    end

    # CSM Number is columns C-F in the source spreadsheet concatenated
    # US Style Number is column I

    it "should set CSM numbers for existing product with no CSM custom value" do
      p = FactoryBot(:product)
      expect(@xlc).to receive(:last_row_number).and_return(2)
      expect(@xlc).to receive(:get_row_as_column_hash).with(0, 1).and_return(
        0=>{'value'=>'seas', 'datatype'=>'string'},
        2=>{'value'=>'140', 'datatype'=>'string'},
        3=>{'value'=>'ABCDE', 'datatype'=>'string'},
        4=>{'value'=>'FGHIJ', 'datatype'=>'string'},
        5=>{'value'=>'KLMNO', 'datatype'=>'string'},
        8=>{'value'=>p.unique_identifier, 'datatype'=>'string'},
        13=>{'value'=>'CSMDEPT', 'datatype'=>'string'}
      )
      expect(@xlc).to receive(:get_row_as_column_hash).with(0, 2).and_return(
        0=>{'value'=>'seas', 'datatype'=>'string'},
        2=>{'value'=>'ZZZ', 'datatype'=>'string'},
        3=>{'value'=>'PQRST', 'datatype'=>'string'},
        4=>{'value'=>'UVWXY', 'datatype'=>'string'},
        5=>{'value'=>'Z1234', 'datatype'=>'string'},
        8=>{'value'=>p.unique_identifier, 'datatype'=>'string'},
        13=>{'value'=>'CSMDEPT', 'datatype'=>'string'}
      )
      @h.process FactoryBot(:user)
      expect(p.custom_value(cdefs[:csm_numbers])).to eq("140ABCDEFGHIJKLMNO\nZZZPQRSTUVWXYZ1234")
    end

    it "should include non-contiguous CSM numbers for a product" do
      p = FactoryBot(:product)
      expect(@xlc).to receive(:last_row_number).and_return(3)
      expect(@xlc).to receive(:get_row_as_column_hash).with(0, 1).and_return(
        0=>{'value'=>'seas', 'datatype'=>'string'},
        2=>{'value'=>'140', 'datatype'=>'string'},
        3=>{'value'=>'ABCDE', 'datatype'=>'string'},
        4=>{'value'=>'FGHIJ', 'datatype'=>'string'},
        5=>{'value'=>'KLMNO', 'datatype'=>'string'},
        8=>{'value'=>p.unique_identifier, 'datatype'=>'string'},
        13=>{'value'=>'CSMDEPT', 'datatype'=>'string'}

      )
      expect(@xlc).to receive(:get_row_as_column_hash).with(0, 2).and_return(
        0=>{'value'=>'seas', 'datatype'=>'string'},
        2=>{'value'=>'140', 'datatype'=>'string'},
        3=>{'value'=>'ABCDE', 'datatype'=>'string'},
        4=>{'value'=>'FGHIJ', 'datatype'=>'string'},
        5=>{'value'=>'KLMNO', 'datatype'=>'string'},
        8=>{'value'=>'something else', 'datatype'=>'string'},
        13=>{'value'=>'CSMDEPT', 'datatype'=>'string'}

      )
      expect(@xlc).to receive(:get_row_as_column_hash).with(0, 3).and_return(
        0=>{'value'=>'seas', 'datatype'=>'string'},
        2=>{'value'=>'ZZZ', 'datatype'=>'string'},
        3=>{'value'=>'PQRST', 'datatype'=>'string'},
        4=>{'value'=>'UVWXY', 'datatype'=>'string'},
        5=>{'value'=>'Z1234', 'datatype'=>'string'},
        8=>{'value'=>p.unique_identifier, 'datatype'=>'string'},
        13=>{'value'=>'CSMDEPT', 'datatype'=>'string'}

      )
      @h.process FactoryBot(:user)
      expect(p.custom_value(cdefs[:csm_numbers])).to eq("140ABCDEFGHIJKLMNO\nZZZPQRSTUVWXYZ1234")
      expect(Product.where(unique_identifier: 'something else').first.custom_value(cdefs[:csm_numbers])).to eq("140ABCDEFGHIJKLMNO")
    end

    it "should create new CSM number for new product" do
      expect(@xlc).to receive(:last_row_number).and_return(1)
      expect(@xlc).to receive(:get_row_as_column_hash).with(0, 1).and_return(
        0=>{'value'=>'seas', 'datatype'=>'string'},
        2=>{'value'=>'140', 'datatype'=>'string'},
        3=>{'value'=>'ABCDE', 'datatype'=>'string'},
        4=>{'value'=>'FGHIJ', 'datatype'=>'string'},
        5=>{'value'=>'KLMNO', 'datatype'=>'string'},
        8=>{'value'=>'something else', 'datatype'=>'string'},
        13=>{'value'=>'CSMDEPT', 'datatype'=>'string'}

      )
      @h.process FactoryBot(:user)
      p = Product.where(unique_identifier: 'something else').first
      expect(p.custom_value(cdefs[:csm_numbers])).to eq("140ABCDEFGHIJKLMNO")
      expect(p.custom_value(cdefs[:csm_department])).to eq('CSMDEPT')
    end

    it "should drop existing CSM numbers not in file" do
      p = FactoryBot(:product)
      p.update_custom_value!(cdefs[:csm_numbers], 'XZY')
      expect(@xlc).to receive(:last_row_number).and_return(1)
      expect(@xlc).to receive(:get_row_as_column_hash).with(0, 1).and_return(
        0=>{'value'=>'seas', 'datatype'=>'string'},
        2=>{'value'=>'140', 'datatype'=>'string'},
        3=>{'value'=>'ABCDE', 'datatype'=>'string'},
        4=>{'value'=>'FGHIJ', 'datatype'=>'string'},
        5=>{'value'=>'KLMNO', 'datatype'=>'string'},
        8=>{'value'=>p.unique_identifier, 'datatype'=>'string'},
        13=>{'value'=>'CSMDEPT', 'datatype'=>'string'}
      )
      @h.process FactoryBot(:user)
      p = Product.find p.id
      expect(p.custom_value(cdefs[:csm_numbers])).to eq("140ABCDEFGHIJKLMNO")
    end

    it "should fail if CSM number is not 18 digits" do
      p = FactoryBot(:product)
      expect(@xlc).to receive(:last_row_number).and_return(1)
      expect(@xlc).to receive(:get_row_as_column_hash).with(0, 1).and_return(
        0=>{'value'=>'seas', 'datatype'=>'string'},
        2=>{'value'=>'140XX', 'datatype'=>'string'},
        3=>{'value'=>'ABCDE', 'datatype'=>'string'},
        4=>{'value'=>'FGHIJ', 'datatype'=>'string'},
        5=>{'value'=>'KLMNO', 'datatype'=>'string'},
        8=>{'value'=>p.unique_identifier, 'datatype'=>'string'},
        13=>{'value'=>'CSMDEPT', 'datatype'=>'string'}
      )
      u = FactoryBot(:user)
      @h.process u
      expect(p.custom_value(cdefs[:csm_numbers])).to be_blank
      expect(u.messages.size).to eq(1)
      expect(u.messages[0].body).to include("File failed: CSM Number at row 2 was not 18 digits \"140XXABCDEFGHIJKLMNO\"")
    end

    it "should not fail for empty lines" do
      expect(@xlc).to receive(:last_row_number).and_return(1)
      expect(@xlc).to receive(:get_row_as_column_hash).with(0, 1).and_return({})
      expect {@h.process FactoryBot(:user)}.to_not change(ErrorLogEntry, :count)
    end

    it "should fail if user cannot edit products" do
      allow_any_instance_of(Product).to receive(:can_edit?).and_return false
      p = FactoryBot(:product)

      expect(@xlc).to receive(:last_row_number).and_return(1)
      expect(@xlc).to receive(:get_row_as_column_hash).with(0, 1).and_return(
        0=>{'value'=>'seas', 'datatype'=>'string'},
        2=>{'value'=>'140', 'datatype'=>'string'},
        3=>{'value'=>'ABCDE', 'datatype'=>'string'},
        4=>{'value'=>'FGHIJ', 'datatype'=>'string'},
        5=>{'value'=>'KLMNO', 'datatype'=>'string'},
        8=>{'value'=>p.unique_identifier, 'datatype'=>'string'},
        13=>{'value'=>'CSMDEPT', 'datatype'=>'string'}
      )
      u = FactoryBot(:user)
      @h.process u
      expect(p.custom_value(cdefs[:csm_numbers])).to be_blank
      expect(u.messages.size).to eq(1)
      expect(u.messages[0].body).to include("File failed: #{u.full_name} can't edit product #{p.unique_identifier}")
    end

    it "should utilize field logic validations" do
      p = FactoryBot(:product)
      rule = FieldValidatorRule.create! model_field_uid: :prod_uid, module_type: 'Product', starts_with: 'ABC'
      expect(@xlc).to receive(:last_row_number).and_return(1)
      expect(@xlc).to receive(:get_row_as_column_hash).with(0, 1).and_return(
        0=>{'value'=>'seas', 'datatype'=>'string'},
        2=>{'value'=>'140', 'datatype'=>'string'},
        3=>{'value'=>'ABCDE', 'datatype'=>'string'},
        4=>{'value'=>'FGHIJ', 'datatype'=>'string'},
        5=>{'value'=>'KLMNO', 'datatype'=>'string'},
        8=>{'value'=>p.unique_identifier, 'datatype'=>'string'},
        13=>{'value'=>'CSMDEPT', 'datatype'=>'string'}
      )
      u = FactoryBot(:user)
      @h.process u
      expect(p.custom_value(cdefs[:csm_numbers])).to be_blank
      expect(u.messages.size).to eq(1)
      # Don't bother trying to determine what the error will be..
      expect(u.messages[0].body).to include("<p>The following CSM data errors were encountered:<ul><li>")
      expect(u.messages[0].body).to end_with("</li></ul></p>")
    end

    context "dates" do

      it "should set first/last csm received dates" do
        p = FactoryBot(:product)
        expect(@xlc).to receive(:last_row_number).and_return(1)
        expect(@xlc).to receive(:get_row_as_column_hash).with(0, 1).and_return(
          0=>{'value'=>'seas', 'datatype'=>'string'},
          2=>{'value'=>'140', 'datatype'=>'string'},
          3=>{'value'=>'ABCDE', 'datatype'=>'string'},
          4=>{'value'=>'FGHIJ', 'datatype'=>'string'},
          5=>{'value'=>'KLMNO', 'datatype'=>'string'},
          8=>{'value'=>p.unique_identifier, 'datatype'=>'string'},
          13=>{'value'=>'CSMDEPT', 'datatype'=>'string'}
        )
        @h.process FactoryBot(:user)
        expect(p.custom_value(cdefs[:csm_received_date_first]).strftime("%y%m%d")).to eq(0.seconds.ago.strftime("%y%m%d"))
        expect(p.custom_value(cdefs[:csm_received_date_last]).strftime("%y%m%d")).to eq(0.seconds.ago.strftime("%y%m%d"))
      end

      it "should not change existing first csm received date" do
        p = FactoryBot(:product)
        p.update_custom_value! cdefs[:csm_received_date_first], 1.day.ago
        expect(@xlc).to receive(:last_row_number).and_return(1)
        expect(@xlc).to receive(:get_row_as_column_hash).with(0, 1).and_return(
          0=>{'value'=>'seas', 'datatype'=>'string'},
          2=>{'value'=>'140', 'datatype'=>'string'},
          3=>{'value'=>'ABCDE', 'datatype'=>'string'},
          4=>{'value'=>'FGHIJ', 'datatype'=>'string'},
          5=>{'value'=>'KLMNO', 'datatype'=>'string'},
          8=>{'value'=>p.unique_identifier, 'datatype'=>'string'},
          13=>{'value'=>'CSMDEPT', 'datatype'=>'string'}
        )
        @h.process FactoryBot(:user)
        expect(p.custom_value(cdefs[:csm_received_date_first]).strftime("%y%m%d")).to eq(1.day.ago.strftime("%y%m%d"))
      end
      it "should not move last csm date backwards" do
        p = FactoryBot(:product)
        p.update_custom_value! cdefs[:csm_received_date_last], 1.day.from_now
        expect(@xlc).to receive(:last_row_number).and_return(1)
        expect(@xlc).to receive(:get_row_as_column_hash).with(0, 1).and_return(
          0=>{'value'=>'seas', 'datatype'=>'string'},
          2=>{'value'=>'140', 'datatype'=>'string'},
          3=>{'value'=>'ABCDE', 'datatype'=>'string'},
          4=>{'value'=>'FGHIJ', 'datatype'=>'string'},
          5=>{'value'=>'KLMNO', 'datatype'=>'string'},
          8=>{'value'=>p.unique_identifier, 'datatype'=>'string'},
          13=>{'value'=>'CSMDEPT', 'datatype'=>'string'}
        )
        @h.process FactoryBot(:user)
        expect(p.custom_value(cdefs[:csm_received_date_last]).strftime("%y%m%d")).to eq(1.day.from_now.strftime("%y%m%d"))
      end
      it "should respect override for file received date" do
        p = FactoryBot(:product)
        expect(@xlc).to receive(:last_row_number).and_return(1)
        expect(@xlc).to receive(:get_row_as_column_hash).with(0, 1).and_return(
          0=>{'value'=>'seas', 'datatype'=>'string'},
          2=>{'value'=>'140', 'datatype'=>'string'},
          3=>{'value'=>'ABCDE', 'datatype'=>'string'},
          4=>{'value'=>'FGHIJ', 'datatype'=>'string'},
          5=>{'value'=>'KLMNO', 'datatype'=>'string'},
          8=>{'value'=>p.unique_identifier, 'datatype'=>'string'},
          13=>{'value'=>'CSMDEPT', 'datatype'=>'string'}
        )
        @h = described_class.new @cf, 1.day.from_now
        @h.process FactoryBot(:user)
        expect(p.custom_value(cdefs[:csm_received_date_last]).strftime("%y%m%d")).to eq(1.day.from_now.strftime("%y%m%d"))
      end
    end
  end

  describe "process_from_s3" do
    before :each do
      @user = FactoryBot(:user, username: 'rbjork')
      @f = Tempfile.new ['file', '.txt']
      @f << "content"
      @f.flush
      @f.rewind
      Attachment.add_original_filename_method @f
      @f.original_filename = "file.txt"
    end

    after :each do
      @f.close! unless @f.closed?
    end

    it "creates a custom file from s3 attachment and processes it" do
      expect(OpenChain::S3).to receive(:download_to_tempfile).with('bucket', 'path', original_filename: "myfile.txt").and_yield @f
      expect_any_instance_of(CustomFile).to receive(:process).with @user
      described_class.process_from_s3 'bucket', 'path', original_filename: "myfile.txt"

      cf = CustomFile.first
      expect(cf).not_to be_nil
      expect(cf.attached_file_name).to eq @f.original_filename
    end
  end
end
