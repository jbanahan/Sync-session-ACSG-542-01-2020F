require 'spec_helper'

describe CustomReportBillingAllocationByValue do
  before :each do
    @u = Factory(:master_user)
    @u.company.update_attributes(:broker=>true)
    @u.stub(:view_broker_invoices?).and_return(true)
    @klass = CustomReportBillingAllocationByValue
  end
  describe :static_methods do
    it "should allow users who can view broker invoices" do
      @klass.can_view?(@u).should be_true
    end
    it "should not allow users who cannot view broker invoices" do
      @u.stub(:view_broker_invoices?).and_return(false)
      @klass.can_view?(@u).should be_false
    end
    it "should show all entry, commercial invoice, commercial invoice line, commercial invoice tariff fields" do
      cfa = @klass.column_fields_available(@u)
      cfa.size.should == CoreModule::ENTRY.model_fields_including_children(@u).values.size
      cfa.should include(ModelField.find_by_uid(:ent_entry_num))
      cfa.should include(ModelField.find_by_uid(:ci_invoice_number))
      cfa.should include(ModelField.find_by_uid(:cil_line_number))
      cfa.should include(ModelField.find_by_uid(:cit_hts_code))
    end
    it "should allow parameters for only Broker Invoice header fields" do
      cfa = @klass.criterion_fields_available(@u)
      cfa.size.should == CoreModule::BROKER_INVOICE.model_fields.values.size
      cfa.should == CoreModule::BROKER_INVOICE.model_fields.values
      cfa.should include(ModelField.find_by_uid(:bi_entry_num))
      cfa.should_not include(ModelField.find_by_uid(:bi_line_charge_code))
    end
  end

  describe :run do
    before :each do
      @ent = Entry.create!(:entry_number=>"12345678901",:broker_reference=>"4567890",:importer_id=>Factory(:company).id)
      @ci_1 = @ent.commercial_invoices.create!(:invoice_number=>"ci_1")
      @cil_1_1 = @ci_1.commercial_invoice_lines.create!(:line_number=>"1",:value=>50)
      @cil_1_2 = @ci_1.commercial_invoice_lines.create!(:line_number=>"2",:value=>200)
      @bi = @ent.broker_invoices.create!(:invoice_date=>0.seconds.ago,:invoice_total=>250, :invoice_number=>"INV#")
      @bil_1 = @bi.broker_invoice_lines.create!(:charge_description=>"C1",:charge_amount=>"50",:charge_code=>'CC1')
    end
    context "charge categories" do
      before :each do
        @imp = @ent.importer
        @imp.charge_categories.create!(:charge_code=>'CC1',:category=>'X')
      end
      it "should use charge categories if they exist" do
        arrays = @klass.new.to_arrays @u
        heading_row = arrays.first
        heading_row.should have(5).headings
        heading_row[4].should == "X"
        [10,40].each_with_index do |val,i|
          arrays[i+1][4].should == val
        end
      end
      it "should total amounts into categories across multiple codes" do
        @imp.charge_categories.create!(:charge_code=>'CC2',:category=>'X')
        @bi.broker_invoice_lines.create!(:charge_description=>"something",:charge_amount=>250,:charge_code=>'CC2')
        arrays = @klass.new.to_arrays @u
        heading_row = arrays.first
        heading_row.should have(5).headings
        heading_row[4].should == "X"
        [60,240].each_with_index do |val,i|
          arrays[i+1][4].should == val
        end
      end
      it "should put uncategoriezed amounts into Other Charges category" do
        @bi.broker_invoice_lines.create!(:charge_description=>"something",:charge_amount=>250,:charge_code=>'CC2')
        arrays = @klass.new.to_arrays @u
        heading_row = arrays.first
        heading_row.should have(6).headings
        heading_row[4].should == "X"
        heading_row[5].should == "Other Charges"
        [[10,50],[40,200]].each_with_index do |val,i|
          arrays[i+1][4].should == val[0]
          arrays[i+1][5].should == val[1]
        end
      end
    end
    it "should include base headings" do
      arrays = @klass.new.to_arrays @u
      heading_row = arrays.first
      heading_row.should have(5).headings
      heading_row[0].should == ModelField.find_by_uid(:bi_invoice_number).label
      heading_row[1].should == ModelField.find_by_uid(:bi_invoice_date).label
      heading_row[2].should == "#{ModelField.find_by_uid(:bi_invoice_total).label} (not prorated)"
      heading_row[3].should == "Broker Invoice - Prorated Line Total"
      heading_row[4].should == "C1"
    end
    it "should include custom column headings" do
      rpt = @klass.new
      rpt.search_columns.build(:rank=>0,:model_field_uid=>:ent_entry_num)
      rpt.search_columns.build(:rank=>1,:model_field_uid=>:cil_line_number)
      arrays = rpt.to_arrays @u
      heading_row = arrays.first
      heading_row.should have(7).headings
      heading_row[0].should == ModelField.find_by_uid(:ent_entry_num).label
      heading_row[1].should == ModelField.find_by_uid(:cil_line_number).label
      heading_row[2].should == ModelField.find_by_uid(:bi_invoice_number).label
    end
    it "should include prorated charges" do
      arrays = @klass.new.to_arrays @u
      arrays.should have(3).rows #heading and row for each commercial invoice line
      arrays[1][3].should == 10
      arrays[2][3].should == 40
    end
    it "should include base broker invoice fields" do
      arrays = @klass.new.to_arrays @u
      arrays[1][0].should == @bi.invoice_number
      arrays[1][1].should == @bi.invoice_date.to_date 
      arrays[1][2].should == 250
      arrays[2][0].should == @bi.invoice_number
      arrays[2][1].should == @bi.invoice_date.to_date
      arrays[2][2].should == 250
    end
    it "should include entry header fields" do
      rpt = @klass.new
      rpt.search_columns.build(:rank=>0,:model_field_uid=>:ent_entry_num)
      arrays = rpt.to_arrays @u
      (1..2).each do |row|
        arrays[row][0].should == @ent.entry_number
        arrays[row][1].should == @bi.invoice_number
      end
    end
    it "should include commercial invoice fields" do
      rpt = @klass.new
      rpt.search_columns.build(:rank=>0,:model_field_uid=>:ci_invoice_number)
      arrays = rpt.to_arrays @u
      (1..2).each do |row|
        arrays[row][0].should == @ci_1.invoice_number
        arrays[row][1].should == @bi.invoice_number
      end
    end
    it "should filter by broker invoice header information" do
      @ent_2 = Entry.create!(:entry_number=>"9999",:broker_reference=>"5555")
      @ci_2 = @ent_2.commercial_invoices.create!(:invoice_number=>"ci_2")
      @cil_2_1 = @ci_2.commercial_invoice_lines.create!(:line_number=>"1",:value=>100)
      @cil_2_2 = @ci_2.commercial_invoice_lines.create!(:line_number=>"2",:value=>100)
      @bi_2 = @ent_2.broker_invoices.create!(:invoice_date=>0.seconds.ago,:invoice_total=>100,:invoice_number=>'bi_2')
      @bi_2.broker_invoice_lines.create!(:charge_description=>"C1",:charge_amount=>"1000")
      # Adding multiple broker invoice lines resulted in a bug causing duplicate output lines (adding a second here to make 
      # sure we're preventing that)
      @bi_2.broker_invoice_lines.create!(:charge_description=>"something",:charge_amount=>250,:charge_code=>'CC2')
      rpt = @klass.new
      rpt.search_criterions.build(:model_field_uid=>:bi_entry_num,:operator=>"eq",:value=>"9999")
      arrays = rpt.to_arrays @u
      arrays.should have(3).rows
      arrays[1][0].should == @bi_2.invoice_number
      arrays[1][3].should == BigDecimal.new(625)
      arrays[1][4].should == 500
      arrays[1][5].should == 125
    end
    it "should include hyperlinks" do
      MasterSetup.get.update_attributes(:request_host=>"http://xxxx")
      arrays = @klass.new(:include_links=>true).to_arrays @u
      arrays.should have(3).rows
      arrays[0][0].should eq "Web Links"
      (1..2).each {|i| arrays[i][0].should == @ent.view_url}
    end
    it "should subtract rounding allocation extra penny from last line" do
      @cil_1_1.update_attributes(:value=>27)
      @cil_1_2.update_attributes(:value=>198)
      @ci_1.commercial_invoice_lines.create!(:line_number=>"3",:value=>50)
      @ci_1.commercial_invoice_lines.create!(:line_number=>"4",:value=>56)
      @bil_1.update_attributes(:charge_amount=>100)
      arrays = @klass.new.to_arrays @u
      arrays[1][3].should == 8.16
      arrays[2][3].should == 59.82
      arrays[3][3].should == 15.11
      arrays[4][3].should == 16.91 #subtracted extra penny
    end
    it "should add rounding allocation extra penny to last line" do
      @cil_1_1.update_attributes(:value=>100)
      @cil_1_2.update_attributes(:value=>100)
      @ci_1.commercial_invoice_lines.create!(:line_number=>"3",:value=>50)
      @ci_1.commercial_invoice_lines.create!(:line_number=>"4",:value=>60)
      @ci_1.commercial_invoice_lines.create!(:line_number=>"5",:value=>48)
      @bil_1.update_attributes(:charge_amount=>54.86)
      arrays = @klass.new.to_arrays @u
      arrays[1][3].should == 15.32
      arrays[2][3].should == 15.32
      arrays[3][3].should == 7.66
      arrays[4][3].should == 9.19
      arrays[5][3].should == 7.37 #added extra penny
    end
    it "should not include charge type D" do
      @bi.broker_invoice_lines.create!(:charge_type=>"D",:charge_description=>"CD2",:charge_amount=>7)
      arrays = @klass.new.to_arrays @u
      arrays.first.should have(5).columns
      arrays.first.last.should == "C1"
      arrays[1].should have(5).columns
      arrays[1].last.should == 10 
    end
    it "should use tariff quantity if value is nil or 0" do
      @cil_1_1.update_attributes(:value=>0)
      @cil_1_1.commercial_invoice_tariffs.create!(:entered_value=>60)
      @cil_1_2.update_attributes(:value=>0)
      @cil_1_2.commercial_invoice_tariffs.create!(:entered_value=>40)
      @cil_1_2.commercial_invoice_tariffs.create!(:entered_value=>20)
      arrays = @klass.new.to_arrays @u
      arrays.should have(3).rows
      arrays[1][3].should == 30
      arrays[2][3].should == 20 #use the first tariff row
    end
    it "should secure entries for importers" do
      imp_user = Factory(:importer_user)
      @e2 = Entry.create!(:broker_reference=>'8888',:importer_id=>imp_user.company_id)
      @e2.broker_invoices.
        create!(:invoice_date=>0.seconds.ago,:invoice_total=>20,:invoice_number=>'e2').
        broker_invoice_lines.create!(:charge_description=>"CDX",:charge_amount=>20)
      @e2.commercial_invoices.create!(:invoice_number=>"X").
        commercial_invoice_lines.create!(:value=>100)
      arrays = @klass.new.to_arrays imp_user #should not include entry from before(:each)
      arrays.should have(2).rows
      arrays[0][4].should == "CDX"
      arrays[1][4].should == 20
    end
    it "should accumulate multiple broker invoice lines with the same charge description" do
      @bi.broker_invoice_lines.create(:charge_description=>@bil_1.charge_description,:charge_amount=>10)
      arrays = @klass.new.to_arrays @u
      arrays.should have(3).rows
      arrays[1][3].should == 12
      arrays[2][3].should == 48
    end
    it "should truncate on row limit" do
      arrays = @klass.new.to_arrays @u, 1
      arrays.should have(2).rows
      arrays[1][3].should == 10
    end
    it "should truncate ISF charges" do
      @bil_1.update_attributes(:charge_description=>"ISF #12312391219")
      @bi.broker_invoice_lines.create(:charge_description=>"ISF #8855858",:charge_amount=>10)
      arrays = @klass.new.to_arrays @u
      arrays.should have(3).rows
      arrays.first.should have(5).columns
      arrays.first.last.should == "ISF"
      arrays[1][3].should == 12
      arrays[2][3].should == 48
    end
    it "should order by entry number" do
      @ent_2 = Entry.create!(:entry_number=>"11111",:broker_reference=>"11111")
      @ci_2 = @ent_2.commercial_invoices.create!(:invoice_number=>"ci_2")
      @cil_2_1 = @ci_2.commercial_invoice_lines.create!(:line_number=>"1",:value=>100)
      @bi_2 = @ent_2.broker_invoices.create!(:invoice_date=>0.seconds.ago,:invoice_total=>100,:invoice_number=>'bi_2')
      
      rpt = @klass.new
      rpt.search_criterions.build(:model_field_uid=>:bi_entry_num,:operator=>"in",:value=>"#{@ent.entry_number}\n#{@ent_2.entry_number}")
      arrays = rpt.to_arrays @u
      
      arrays.should have(4).rows
      arrays[1][0].should == @bi_2.invoice_number
      arrays[2][0].should == @bi.invoice_number
    end
  end
end
