require 'spec_helper'

describe ImportedFile do

  describe 'email_updated_file' do
    it 'should generate and send the file' do
      current_user = Factory(:user)
      to = 'a@b.com'
      cc = 'c@d.com'
      subj = 's'
      body = 'b'
      s3_path = 'x/y/z'
      original_attachment_name = 'abc.xls'
      f = Factory(:imported_file, :user=>current_user, :attached_file_name=>original_attachment_name)
      mail = mock "mail delivery"
      mail.stub(:deliver!).and_return(nil)
      OpenMailer.should_receive(:send_s3_file).with(current_user,to,cc,subj,body,'chain-io',s3_path,original_attachment_name).and_return(mail)
      f.should_receive(:make_updated_file).and_return(s3_path)
      
      f.email_updated_file current_user, to, cc, subj, body
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

end
