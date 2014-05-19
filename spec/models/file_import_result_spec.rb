require 'spec_helper'

describe FileImportResult do

  before :each do
    @user = Factory(:master_user,:email=>'a@example.com')
  end

  describe :download_results do
    before :each do
      @imported_file = Factory(:imported_file, attached_file_name: "file name")
      @fir = Factory(:file_import_result, imported_file: @imported_file)
      @user.messages.delete_all

      @cr1 = Factory(:change_record, failed: true, record_sequence_number: 1)
      @cr2 = Factory(:change_record, failed: false, record_sequence_number: 2)
      @fir.change_records << @cr1
      @fir.change_records << @cr2
    end

    it "should create a new attachment" do
      @fir.download_results(true, @user.id)
      a = Attachment.last
      a.attached_file_name.should == "file name - Results.csv"
      a.created_at.should > Time.now - 15.seconds
      a.attachable_type.should == "FileImportResult"
    end

    it "should create a message for the user if delayed" do
      @fir.download_results(true, @user.id, true)
      @user.reload
      @user.messages.length.should == 1
      @user.messages.last.subject.should == "File Import Result Prepared for Download"
    end

    it "should not create a message for the user if not delayed" do
      @fir.download_results(true, @user.id)
      @user.messages.length.should == 0
    end

    it "should skip successful records when include_all is false" do
      ChangeRecord.any_instance.should_receive(:record_sequence_number).exactly(1).times
      @fir.download_results(false, @user.id)
    end

    it "should include successful records when include_all is true" do
      @cr1.should_receive(:record_sequence_number)
      @cr2.should_receive(:record_sequence_number)
      @fir.download_results(true, @user.id)
    end

    it "should return the created attachment" do
      @fir.download_results(true, @user.id).class.to_s.should == "Attachment"
    end


  end

  describe :time_to_process do
    it "should return nil if no started_at" do
      FileImportResult.new(:finished_at=>0.seconds.ago).time_to_process.should be_nil
    end
    it "should return nil if no finished_at" do
      FileImportResult.new(:started_at=>0.seconds.ago).time_to_process.should be_nil
    end
    it "should return minutes" do
      FileImportResult.new(:started_at=>3.minutes.ago,:finished_at=>0.minutes.ago).time_to_process.should == 3
    end
    it "should return 1 minute even if rounding to zero" do
      FileImportResult.new(:started_at=>2.seconds.ago,:finished_at=>0.seconds.ago).time_to_process.should == 1
    end
  end
  it 'should only find unique changed objects' do
    i_file = ImportedFile.create!(:module_type=>"Product",:update_mode=>'any')
    fir = i_file.file_import_results.create!
    3.times do |i| #add 3 products twice for 6 total change records
      p = Product.create!(:unique_identifier=>"#{i}pid")
      2.times { |z| fir.change_records.create!(:recordable=>p) }
    end
    co = fir.changed_objects
    co.should have(3).items
    3.times do |i|
      co.include?(Product.where(:unique_identifier=>"#{i}pid").first).should be_true
    end
  end
  it 'should allow additional filters on changed_objects' do
    i_file = ImportedFile.create!(:module_type=>"Product",:update_mode=>'any')
    fir = i_file.file_import_results.create!
    3.times do |i| #add 3 products twice for 6 total change records
      p = Product.create!(:unique_identifier=>"#{i}pid")
      2.times { |z| fir.change_records.create!(:recordable=>p) }
    end
    co = fir.changed_objects [SearchCriterion.new(:model_field_uid=>"prod_uid",:operator=>"eq",:value=>"1pid")]
    co.should have(1).item
    co.first.should == Product.where(:unique_identifier=>"1pid").first
  end
  it 'should set changed_object_count on save' do
    file_import_result = Factory(:file_import_result)
    3.times do |i| 
      p = Factory(:product)
      file_import_result.change_records.create!(:recordable => p)
    end
    file_import_result.finished_at = Time.now
    file_import_result.save!
    file_import_result.reload
    file_import_result.changed_object_count.should == 3
  end

end
