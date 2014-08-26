# encoding: utf-8
require 'spec_helper'

describe ImportedFile do
  describe :result_keys_where do
    it "should build proper where clause" do
      f = ImportedFile.new :id => 25

      results = [1,2,3]
      query = nil
      f.should_receive(:execute_query) do |q|
        query = q
        [[1], [2], [3]]
      end

      result_keys = f.result_keys
      query.should eq "select distinct recordable_id from change_records inner join (select id from file_import_results where imported_file_id = #{f.id} order by finished_at DESC limit 1) as fir ON change_records.file_import_result_id = fir.id"
      result_keys.should eq [1, 2, 3]
    end
  end
  describe :result_keys do
    it "should return empty array if no file import results" do
      f = Factory(:imported_file)
      f.result_keys.should == []
    end
    it "should return results" do
      f = Factory(:imported_file)
      fir = f.file_import_results.create!(:finished_at=>Time.now) #only shows for last finished result
      p1 = Factory(:product)
      p2 = Factory(:product)
      [p1,p2].each {|p| fir.change_records.create!(:recordable=>p)}
      f.result_keys.should == [p1.id,p2.id]
    end
  end

  describe 'email_updated_file' do
    it 'should generate and send the file' do
      current_user = Factory(:user)
      to = 'a@b.com'
      cc = 'c@d.com'
      subj = 's'
      body = 'b'
      s3_path = 'x/y/z'
      original_attachment_name = 'abc.xls'
      temp = Tempfile.new ["abc", ".xls"]
      begin
        f = Factory(:imported_file, :user=>current_user, :attached_file_name=>original_attachment_name)
        mail = mock "mail delivery"
        mail.stub(:deliver!).and_return(nil)
        OpenMailer.should_receive(:send_s3_file).with(current_user,to,cc,subj,body,'chain-io',s3_path,original_attachment_name).and_return(mail)
        f.should_receive(:make_updated_file).and_return(s3_path)
        f.should_receive(:make_imported_file_download_from_s3_path).with(s3_path,current_user,[]).and_call_original
        OpenChain::S3.should_receive(:download_to_tempfile).with('chain-io', s3_path).and_return(temp)
        f.email_updated_file current_user, to, cc, subj, body
      ensure 
        temp.close!
      end
    end
  end
  describe 'make_updated_file' do
    context 'product' do
      before :each do 
        @xlc = mock "XLClient"
        @attached = mock "Attachment"
        @attached.should_receive(:path).and_return("some/location.xls")
        OpenChain::XLClient.should_receive(:new).with("some/location.xls").and_return(@xlc)
        @imported_file = Factory(:imported_file,:module_type=>"Product",:user=>Factory(:user),:attached_file_name=>'abc.xls')
        @imported_file.should_receive(:attached).and_return(@attached)
        success_hash = {"result"=>"success"}
        @expected_alternate_location = /#{MasterSetup.get.uuid}\/updated_imported_files\/#{@imported_file.user_id}\/[0-9]{10}\.xls/
        @xlc.should_receive(:save).with(@expected_alternate_location).and_return(success_hash)
      end
      it 'should save the result file' do
        @xlc.should_receive(:last_row_number).and_return(-1)
        result = @imported_file.make_updated_file
        result.should match @expected_alternate_location
      end
      it 'should update header level products' do
        ["prod_name","prod_uid"].each_with_index {|v,i| @imported_file.search_columns.create!(:model_field_uid=>v,:rank=>i)}
        p1 = Factory(:product,:name=>"p1name")
        p2 = Factory(:product,:name=>"p2name")
        p3 = Factory(:product,:name=>"p3name")
        @xlc.should_receive(:last_row_number).and_return(2)
        #first row has extra whitespace that should be stripped
        @xlc.should_receive(:get_row).with(0,0).and_return([{"position"=>{"column"=>0},"cell"=>{"value"=>"oldname1","datatype"=>"string"}},{"position"=>{"column"=>1},"cell"=>{"value"=>" #{p1.unique_identifier} ","datatype"=>"string"}}])
        @xlc.should_receive(:get_row).with(0,1).and_return([{"position"=>{"column"=>0},"cell"=>{"value"=>"oldname2","datatype"=>"string"}},{"position"=>{"column"=>1},"cell"=>{"value"=>p2.unique_identifier,"datatype"=>"string"}}])
        @xlc.should_receive(:get_row).with(0,2).and_return([{"position"=>{"column"=>0},"cell"=>{"value"=>"oldname3","datatype"=>"string"}},{"position"=>{"column"=>1},"cell"=>{"value"=>p3.unique_identifier,"datatype"=>"string"}}])
        @xlc.should_receive(:set_cell).with(0,0,0,p1.name)
        @xlc.should_receive(:set_cell).with(0,1,0,p2.name)
        @xlc.should_receive(:set_cell).with(0,2,0,p3.name)
        @imported_file.make_updated_file
      end
      it 'should not clear fields when product missing' do
        missing_value = "missing val"
        ["prod_name","prod_uid"].each_with_index {|v,i| @imported_file.search_columns.create!(:model_field_uid=>v,:rank=>i)}
        @xlc.should_receive(:last_row_number).and_return(0)
        @xlc.should_receive(:get_row).with(0,0).and_return([{"position"=>{"column"=>0},"cell"=>{"value"=>"oldname1","datatype"=>"string"}},{"position"=>{"column"=>1},"cell"=>{"value"=>missing_value,"datatype"=>"string"}}])
        @xlc.should_not_receive(:set_cell).with(0,0,0,"")
        @imported_file.make_updated_file
      end
      it 'should update custom values' do
        cd = Factory(:custom_definition,:module_type=>"Product")
        p = Factory(:product)
        cv = p.get_custom_value(cd)
        cv.value = "x"
        cv.save!
        [cd.model_field_uid,"prod_uid"].each_with_index {|v,i| @imported_file.search_columns.create!(:model_field_uid=>v,:rank=>i)}
        @xlc.should_receive(:last_row_number).and_return(0)
        @xlc.should_receive(:get_row).with(0,0).and_return([{"position"=>{"column"=>1},"cell"=>{"value"=>p.unique_identifier,"datatype"=>"string"}}])
        @xlc.should_receive(:set_cell).with(0,0,0,"x")
        @imported_file.make_updated_file
      end
      it 'should update classification level items' do
        cd = Factory(:custom_definition,:module_type=>"Classification")
        ["prod_uid","class_cntry_iso",cd.model_field_uid].each_with_index {|v,i| @imported_file.search_columns.create!(:model_field_uid=>v,:rank=>i)}
        p = Factory(:product)
        ctry = Factory(:country)
        c = p.classifications.create!(:country_id=>ctry.id)
        cv = c.get_custom_value cd
        cv.value = "y"
        cv.save!
        @xlc.should_receive(:last_row_number).and_return(0)
        @xlc.should_receive(:get_row).with(0,0).and_return([{"position"=>{"column"=>0},"cell"=>{"value"=>p.unique_identifier,"datatype"=>"string"}},
                                                            {"position"=>{"column"=>1},"cell"=>{"value"=>ctry.iso_code,"datatype"=>"string"}},
                                                            {"position"=>{"column"=>2},"cell"=>{"value"=>"q","datatype"=>"string"}}])
        @xlc.should_receive(:set_cell).with(0,0,2,"y")
        @imported_file.make_updated_file
      end
      it 'should clear fields for missing child object' do
        cd = Factory(:custom_definition,:module_type=>"Classification")
        ["prod_uid","class_cntry_iso",cd.model_field_uid].each_with_index {|v,i| @imported_file.search_columns.create!(:model_field_uid=>v,:rank=>i)}
        p = Factory(:product)
        ctry = Factory(:country)
        c = p.classifications.create!(:country_id=>ctry.id)
        cv = c.get_custom_value cd
        cv.value = "y"
        cv.save!
        @xlc.should_receive(:last_row_number).and_return(0)
        @xlc.should_receive(:get_row).with(0,0).and_return([{"position"=>{"column"=>0},"cell"=>{"value"=>p.unique_identifier,"datatype"=>"string"}},
                                                            {"position"=>{"column"=>1},"cell"=>{"value"=>"BAD","datatype"=>"string"}},
                                                            {"position"=>{"column"=>2},"cell"=>{"value"=>"q","datatype"=>"string"}}])
        @xlc.should_receive(:set_cell).with(0,0,2,"")
        @imported_file.make_updated_file
      end

      it 'should update tariff level items' do
        ["prod_uid","class_cntry_iso","hts_line_number","hts_hts_1"].each_with_index {|v,i| @imported_file.search_columns.create!(:model_field_uid=>v,:rank=>i)}
        ctry = Factory(:country)
        bad_product = Factory(:product)
        bad_product.classifications.create!(:country_id=>ctry.id).tariff_records.create(:line_number=>4,:hts_1=>'0984717191')
        p = Factory(:product)
        c = p.classifications.create!(:country_id=>ctry.id)
        t = c.tariff_records.create(:line_number=>4,:hts_1=>'1234567890')
        @xlc.should_receive(:last_row_number).and_return(0)
        @xlc.should_receive(:get_row).with(0,0).and_return([{"position"=>{"column"=>0},"cell"=>{"value"=>p.unique_identifier,"datatype"=>"string"}},
                                                            {"position"=>{"column"=>1},"cell"=>{"value"=>ctry.iso_code,"datatype"=>"string"}},
                                                            {"position"=>{"column"=>2},"cell"=>{"value"=>t.line_number,"datatype"=>"number"}},
                                                            {"position"=>{"column"=>3},"cell"=>{"value"=>'7777777',"datatype"=>"number"}}])
        @xlc.should_receive(:set_cell).with(0,0,3,"1234567890".hts_format)
        @imported_file.make_updated_file
      end
      it 'should add extra countries' do
        ["prod_uid","class_cntry_iso","hts_line_number","hts_hts_1"].each_with_index {|v,i| @imported_file.search_columns.create!(:model_field_uid=>v,:rank=>i)}
        ctry = Factory(:country)
        ctry_2 = Factory(:country)
        bad_product = Factory(:product)
        bad_product.classifications.create!(:country_id=>ctry.id).tariff_records.create(:line_number=>4,:hts_1=>'0984717191')
        
        p_a = Factory(:product)
        c_a = p_a.classifications.create!(:country_id=>ctry.id)
        t_a = c_a.tariff_records.create(:line_number=>4,:hts_1=>'1234567890')
        c_a_2 = p_a.classifications.create!(:country_id=>ctry_2.id)
        t_a_2 = c_a_2.tariff_records.create!(:line_number=>4,:hts_1=>'988777789')

        p_b = Factory(:product)
        c_b = p_b.classifications.create!(:country_id=>ctry.id)
        t_b = c_b.tariff_records.create(:line_number=>4,:hts_1=>'0987654321')
        c_b_2 = p_b.classifications.create!(:country_id=>ctry_2.id)
        t_b_2 = c_b_2.tariff_records.create!(:line_number=>4,:hts_1=>'44444444')

        @xlc.should_receive(:last_row_number).exactly(4).times.and_return(1,1,2,3)
        @xlc.should_receive(:get_row).with(0,0).and_return([{"position"=>{"column"=>0},"cell"=>{"value"=>p_a.unique_identifier,"datatype"=>"string"}},
                                                            {"position"=>{"column"=>1},"cell"=>{"value"=>ctry.iso_code,"datatype"=>"string"}},
                                                            {"position"=>{"column"=>2},"cell"=>{"value"=>t_a.line_number,"datatype"=>"number"}},
                                                            {"position"=>{"column"=>3},"cell"=>{"value"=>'7777777',"datatype"=>"number"}}])
        @xlc.should_receive(:get_row).with(0,1).and_return([{"position"=>{"column"=>0},"cell"=>{"value"=>p_b.unique_identifier,"datatype"=>"string"}},
                                                            {"position"=>{"column"=>1},"cell"=>{"value"=>ctry.iso_code,"datatype"=>"string"}},
                                                            {"position"=>{"column"=>2},"cell"=>{"value"=>t_b.line_number,"datatype"=>"number"}},
                                                            {"position"=>{"column"=>3},"cell"=>{"value"=>'7777777',"datatype"=>"number"}}])
        @xlc.should_receive(:copy_row).with(0,0,2)
        @xlc.should_receive(:copy_row).with(0,1,3)
        @xlc.should_receive(:set_cell).with(0,2,1,ctry_2.iso_code)
        @xlc.should_receive(:set_cell).with(0,3,1,ctry_2.iso_code)
        @xlc.should_receive(:get_row).with(0,2).and_return([{"position"=>{"column"=>0},"cell"=>{"value"=>p_a.unique_identifier,"datatype"=>"string"}},
                                                            {"position"=>{"column"=>1},"cell"=>{"value"=>ctry_2.iso_code,"datatype"=>"string"}},
                                                            {"position"=>{"column"=>2},"cell"=>{"value"=>t_a.line_number,"datatype"=>"number"}},
                                                            {"position"=>{"column"=>3},"cell"=>{"value"=>'7777777',"datatype"=>"number"}}])
        @xlc.should_receive(:get_row).with(0,3).and_return([{"position"=>{"column"=>0},"cell"=>{"value"=>p_b.unique_identifier,"datatype"=>"string"}},
                                                            {"position"=>{"column"=>1},"cell"=>{"value"=>ctry_2.iso_code,"datatype"=>"string"}},
                                                            {"position"=>{"column"=>2},"cell"=>{"value"=>t_b.line_number,"datatype"=>"number"}},
                                                            {"position"=>{"column"=>3},"cell"=>{"value"=>'7777777',"datatype"=>"number"}}])
        @xlc.should_receive(:set_cell).with(0,0,3,t_a.hts_1.hts_format)
        @xlc.should_receive(:set_cell).with(0,1,3,t_b.hts_1.hts_format)
        @xlc.should_receive(:set_cell).with(0,2,3,t_a_2.hts_1.hts_format)
        @xlc.should_receive(:set_cell).with(0,3,3,t_b_2.hts_1.hts_format)
        @imported_file.make_updated_file :extra_country_ids=>[ctry_2.id]
      end
    end
  end

  describe "sanitize callback" do
    it "should sanitize the attached filename" do
      i = ImportedFile.new :module_type => "Product", :starting_row => 1, :starting_column => 1, :update_mode => "any"
      i.attached_file_name = "照片\/:*?\"<>|\001\002\003\004\005\006\007\010\011\012\013\014\015\016\017\020\021\022\023\024\025\026\027\030\031.jpg"
      i.save
      i.attached_file_name.should == "___________________________________.jpg"
    end
  end

  describe "process" do
    before :each do
      @u = Factory(:user)
      @i = Factory(:imported_file, :search_setup => Factory(:search_setup))
    end
    it "should process an imported file" do
    
      @i.search_setup.search_columns.create! model_field_uid: :unique_identifier


      ImportedFile::FileImportProcessJob.any_instance.should_receive(:perform)
      r = @i.process @u
      r.should be_true

      # Make sure the imported file had search columns imported
      @i.search_columns.size.should eq 1
      @i.search_columns.first.model_field_uid.should eq "unique_identifier"
    end

    it "should process an imported file on delayed job queue" do
      
      ImportedFile::FileImportProcessJob.any_instance.should_receive(:enqueue_job)
      r = @i.process @u, defer: true
      r.should be_true
    end

    it "should return false if errors were found while processing" do
      ImportedFile::FileImportProcessJob.any_instance.should_receive(:perform) do
        @i.errors[:base] << "Error"
        nil
      end

      r = @i.process @u
      r.should be_false
    end
  end

  describe "FileImportProcessJob#perform" do
    before :each do
      @u = Factory(:user)
      @i = Factory(:imported_file, :search_setup => Factory(:search_setup), :attached_file_name => "test.txt")
    end

    it "should call process on FileImportProcessor" do 
      FileImportProcessor.should_receive(:process) do |file, listener|
        file.should be @i
        listener[0].class.should eq ImportedFile::FileImportProcessorListener
      end

      ImportedFile::FileImportProcessJob.new(@i, @u).perform
    end

    it "should requeue if another job with the same file is running" do
      # Need to create two here to get real conditions, current job + another running same file
      Delayed::Job.enqueue ImportedFile::FileImportProcessJob.new(@i, @u)
      Delayed::Job.enqueue ImportedFile::FileImportProcessJob.new(@i, @u)
      ActiveRecord::Base.connection.execute("update delayed_jobs set locked_by = 'test', locked_at = now()")
      FileImportProcessor.should_not_receive(:process)

      ImportedFile::FileImportProcessJob.new(@i, @u).perform

      jobs = Delayed::Job.where("run_at > ?", Time.zone.now).all
      jobs.size.should eq 1

      # Make sure we're enqueueing the file to be run (fuzzily) between around 3 and 3.5 minutes later.
      jobs[0].run_at.should >= (Time.zone.now + 175.seconds)
      jobs[0].run_at.should <= (Time.zone.now + 215.seconds)
    end

    it "should email if errors were encountered" do
      error =StandardError.new "Test"
      FileImportProcessor.should_receive(:process) do 
        raise error
      end

      error.should_receive(:log_me).with ["Imported File ID: #{@i.id}"]

      ms = double("MasterSetup")
      MasterSetup.should_receive(:get).and_return ms
      ms.should_receive(:custom_feature?).with("LogImportedFileErrors").and_return true

      mail = double("mail")
      mail.should_receive :deliver
      OpenMailer.should_receive(:send_imported_file_process_fail).with(@i, @i.search_setup.user).and_return mail
      ImportedFile::FileImportProcessJob.new(@i, @u).perform
    end
  end

  describe "process_integration_imported_file" do
    before :each do
      @temp = Tempfile.new ['temp', '.csv']
      Attachment.add_original_filename_method @temp
      @temp.original_filename = 'file.csv'

    end
    it "downloads file from s3 and imports it" do
      user = Factory(:user)
      ss = Factory(:search_setup, user: user)
      OpenChain::S3.should_receive(:download_to_tempfile).with("bucket", "path", original_filename: "myfile.csv").and_yield @temp
      ImportedFile.any_instance.should_receive(:process).with(user, {defer: true})
      path = "/#{user.username}/to_chain/#{ss.module_type.downcase}/#{ss.name}/myfile.csv"

      ImportedFile.process_integration_imported_file 'bucket', 'path', path

      imp_file = ImportedFile.first
      expect(imp_file).not_to be_nil
      expect(imp_file.module_type).to eq ss.module_type
      expect(imp_file.user).to eq user
      expect(imp_file.attached_file_name).to eq @temp.original_filename
    end

    it "errors if user is missing" do
      user = Factory(:user)
      ss = Factory(:search_setup, user: user)
      path = "/notauser/to_chain/#{ss.module_type.downcase}/#{ss.name}/myfile.csv"
      RuntimeError.any_instance.should_receive(:log_me).with ["Failed to process imported file with original path '#{path}'."]

      ImportedFile.process_integration_imported_file 'bucket', 'path', path
    end

    it "errors if search module is wrong is missing" do
      user = Factory(:user)
      ss = Factory(:search_setup, user: user)
      path = "/#{user.username}/to_chain/notamodule/#{ss.name}/myfile.csv"
      RuntimeError.any_instance.should_receive(:log_me).with ["Failed to process imported file with original path '#{path}'."]

      ImportedFile.process_integration_imported_file 'bucket', 'path', path
    end

    it "errors if search name is wrong" do
      user = Factory(:user)
      ss = Factory(:search_setup, user: user)
      path = "/#{user.username}/to_chain/#{ss.module_type.downcase}/notaname/myfile.csv"
      RuntimeError.any_instance.should_receive(:log_me).with ["Failed to process imported file with original path '#{path}'."]

      ImportedFile.process_integration_imported_file 'bucket', 'path', path
    end
  end
end
