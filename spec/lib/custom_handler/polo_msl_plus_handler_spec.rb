require 'spec_helper'

describe OpenChain::CustomHandler::PoloMslPlusHandler do
  
  context 'security' do
    before :each do
      c = Factory(:company,:master=>true)
      @u = Factory(:user,:company_id=>c.id)
    end
    it 'should allow user who can edit products' do
      @u.product_edit = true
      @u.save!
      OpenChain::CustomHandler::PoloMslPlusHandler.new(nil).can_view?(@u).should be_true
    end
    it 'should not allow user who cannot edit products' do
      OpenChain::CustomHandler::PoloMslPlusHandler.new(nil).can_view?(@u).should be_false
    end
  end
  context 'xlclient_processing' do
    before :each do
      @u = Factory(:user)
      path = 'a'
      attached = mock "Attached"
      @xlc = mock "XLClient"
      @cf = Factory(:custom_file,:file_type=>'OpenChain::CustomHandler::PoloMslPlusHandler',:attached_file_name=>'something.xls') 
      @cf.should_receive(:attached).at_least(1).and_return(attached)
      attached.should_receive(:path).and_return(path)
      OpenChain::XLClient.should_receive(:new).with(path).and_return(@xlc)
    end
    describe 'process' do
      before :each do
        #make custom fields
        @cd_hash = {}
        ["Board Number","Season","Fiber Content %s","GCC Description","MSL+ HTS Description"].each {|label| @cd_hash[label] = Factory(:custom_definition,:label=>label,:module_type=>'Product')}

        @data = [{:style=>'abcdefg',:board=>'bn123',:season=>'SUM11',:name=>'afja',:fiber=>'123j213l',:gcc=>'gcc1',:msl_hts=>'1235'},
          {:style=>'',:board=>'something'},
          {:style=>'qfiafla',:board=>'bzzz',:season=>'SPR12',:name=>'fdskj',:fiber=>'kjflfad',:gcc=>'gcc3'}
          ]
        @data.each_with_index do |d,i|
          r = [
            {'position'=>{'sheet'=>0,'row'=>i+4,'column'=>11},'cell'=>{'value'=>d[:style],'datatype'=>'string'}},
            {'position'=>{'sheet'=>0,'row'=>i+4,'column'=>12},'cell'=>{'value'=>d[:board],'datatype'=>'string'}},
            {'position'=>{'sheet'=>0,'row'=>i+4,'column'=>9},'cell'=>{'value'=>d[:season],'datatype'=>'string'}},
            {'position'=>{'sheet'=>0,'row'=>i+4,'column'=>20},'cell'=>{'value'=>d[:name],'datatype'=>'string'}},
            {'position'=>{'sheet'=>0,'row'=>i+4,'column'=>21},'cell'=>{'value'=>d[:fiber],'datatype'=>'string'}},
            {'position'=>{'sheet'=>0,'row'=>i+4,'column'=>28},'cell'=>{'value'=>d[:gcc],'datatype'=>'string'}},
            {'position'=>{'sheet'=>0,'row'=>i+4,'column'=>45},'cell'=>{'value'=>d[:msl_hts],'datatype'=>'string'}}
          ]
          @xlc.should_receive(:get_row).with(0,i+4).and_return(r)
        end
        @xlc.should_receive(:last_row_number).with(0).and_return(6)
      end
      it 'should add new styles' do
        OpenChain::CustomHandler::PoloMslPlusHandler.new(@cf).process(@u)
        @data.each do |d|
          next if d[:style].blank? #skip empty row
          result = Product.where(:unique_identifier=>d[:style],:name=>d[:name])
          result.should have(1).product
          p = result.first
          sym_label = {:board=>"Board Number",:season=>"Season",:fiber=>"Fiber Content %s",:gcc=>"GCC Description",:msl_hts=>"MSL+ HTS Description"}
          sym_label.each {|k,v| p.get_custom_value(@cd_hash[v]).value.should == d[k]}
        end
      end
      it 'should set core_module in custom_file' do
        OpenChain::CustomHandler::PoloMslPlusHandler.new(@cf).process(@u)
        CustomFile.find(@cf.id).module_type.should == "Product"
      end
      it 'should update fields in existing style that are blank' do
        p = Factory(:product,:unique_identifier=>@data[0][:style])
        OpenChain::CustomHandler::PoloMslPlusHandler.new(@cf).process(@u)
        p.reload
        p.name.should == @data[0][:name]
        p.get_custom_value(@cd_hash["Board Number"]).value.should == @data[0][:board]
      end
      it 'should not update fields in existing style that are not blank' do
        p = Factory(:product,:unique_identifier=>@data[0][:style],:name=>'something else')
        cv = p.get_custom_value(@cd_hash["Board Number"])
        cv.value = 'another board'
        cv.save!
        OpenChain::CustomHandler::PoloMslPlusHandler.new(@cf).process(@u)
        p = Product.find(p.id)
        p.name.should == 'something else'
        p.get_custom_value(@cd_hash["Board Number"]).value.should == 'another board'
        p.get_custom_value(@cd_hash["Season"]).value.should == @data[0][:season]
      end
      it 'should write custom file records' do
        OpenChain::CustomHandler::PoloMslPlusHandler.new(@cf).process(@u)
        records = @cf.custom_file_records
        records.size.should == 2
        p = Product.all
        records.each do |r|
          p.should include(r.linked_object)
        end
      end
      it 'should clear old custom file records' do
        o = Factory(:order)
        @cf.custom_file_records.create!(:linked_object=>o)
        OpenChain::CustomHandler::PoloMslPlusHandler.new(@cf).process(@u)
        records = @cf.custom_file_records
        records.size.should == 2
        p = Product.all
        records.each do |r|
          p.should include(r.linked_object)
        end
      end
      it 'should error if row is missing style but keep processing' do
        OpenChain::CustomHandler::PoloMslPlusHandler.new(@cf).process(@u).should == ["Row 6 skipped, missing style number."]
      end
      it 'shoud write product history' do
        OpenChain::CustomHandler::PoloMslPlusHandler.new(@cf).process(@u)
        Product.first.entity_snapshots.should have(1).record
      end
    end

    describe 'make updated file' do
      it 'should write values' do
        cd_fiber = Factory(:custom_definition,:module_type=>"Product",:label=>"Fiber Content %s")
        cd_length = Factory(:custom_definition,:module_type=>"Product",:label=>"Length (cm)")
        cd_width = Factory(:custom_definition,:module_type=>"Product",:label=>"Width (cm)")
        cd_height = Factory(:custom_definition,:module_type=>"Product",:label=>"Height (cm)")
        style = 'abc123'
        name = 'nme'
        fiber = '100% cotton'
        height = '10'
        width = '11'
        length = '12'
        gcc_desc = 'gcc'
        iso_codes = ['HK','CN','MO','MY','SG','TW','PH','JP','KR']
        countries = {}
        expected_writes = [[29,'YES'],[44,name],[45,fiber],[119,height],[120,length],[121,width]]
        hts_1_prefix = '1654611'
        hts_2_prefix = '5681351'
        hts_3_prefix = '5684888'
        iso_codes.each_with_index do |c,i| 
          countries[c] = {:country=>Factory(:country,:iso_code=>c),
            :hts_1=>"#{hts_1_prefix}#{i}",:hts_2=>"#{hts_2_prefix}#{i}",:hts_3=>"#{hts_3_prefix}#{i}"}
          expected_writes << [35+i,"#{hts_1_prefix}#{i}".hts_format]
          expected_writes << [48+i,"#{hts_2_prefix}#{i}".hts_format]
          expected_writes << [61+i,"#{hts_3_prefix}#{i}".hts_format]
        end
        OfficialTariff.create!(:country_id=>countries['TW'][:country].id,:hts_code=>countries['TW'][:hts_1],:import_regulations=>'a MP1 b')
        p = Factory(:product,:unique_identifier=>style,:name=>name)
        cv = p.get_custom_value(cd_fiber)
        cv.value = fiber
        cv.save!
        cv = p.get_custom_value(cd_length)
        cv.value = length
        cv.save!
        cv = p.get_custom_value(cd_width)
        cv.value = width
        cv.save!
        cv = p.get_custom_value(cd_height)
        cv.value = height
        cv.save!
        countries.each do |k,v|
          c = p.classifications.create!(:country_id=>v[:country].id)
          c.tariff_records.create!(:hts_1=>v[:hts_1],:hts_2=>v[:hts_2],:hts_3=>v[:hts_3])
        end
        @xlc.should_receive(:last_row_number).with(0).and_return(5)
        style_1_cell = {'cell'=>{'value'=>style,'datatype'=>'string'}}
        style_2_cell = {'cell'=>{'value'=>'missing style','datatype'=>'string'}}
        @xlc.should_receive(:get_cell).with(0,4,11).and_return(style_1_cell)
        @xlc.should_receive(:get_cell).with(0,5,11).and_return(style_2_cell)
        expected_writes.each do |w|
          @xlc.should_receive(:set_cell).with(0,4,w[0],w[1])
        end
        @xlc.should_receive(:save)
        save_location = OpenChain::CustomHandler::PoloMslPlusHandler.new(@cf).make_updated_file(@u)
        save_location.start_with?("#{MasterSetup.get.uuid}/updated_msl_plus_files/").should == true
      end
    end
  end
end
