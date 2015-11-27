require 'spec_helper'

describe OpenChain::CustomHandler::LumberLiquidators::LumberEpdParser do
  before :each do
    @base_struct = Struct.new(:article_num, :variant_id, 
      :vendor_num, :component, :component_thickness,
      :genus, :species, :coo, :row_num)
  end
  describe '#can_view?' do
    it "should fail if custom feature not enabled" do
      u = Factory(:master_user)
      u.stub(:edit_variants?).and_return true
      u.stub(:in_group?).and_return true
      expect(described_class.can_view?(u)).to be_false
    end
    it "should fail if user not master" do
      u = Factory(:user)
      u.stub(:edit_variants?).and_return true
      u.stub(:in_group?).and_return true
      MasterSetup.any_instance.stub(:custom_feature?).and_return true
      expect(described_class.can_view?(u)).to be_false
    end
    it "should fail if user cannot edit variants" do
      u = Factory(:master_user)
      u.should_receive(:edit_variants?).and_return false
      u.stub(:in_group?).and_return true
      MasterSetup.any_instance.stub(:custom_feature?).and_return true
      expect(described_class.can_view?(u)).to be_false
    end

    it 'should fail if user not in PRODUCTCOMP group' do
      u = Factory(:master_user)
      u.stub(:edit_variants?).and_return true
      u.should_receive(:in_group?).and_return false
      MasterSetup.any_instance.stub(:custom_feature?).and_return true
      expect(described_class.can_view?(u)).to be_false
    end

    it 'should pass if user can edit variants, is master, and feature is enabled' do
      u = Factory(:master_user)
      u.should_receive(:edit_variants?).and_return true
      u.should_receive(:in_group?).with('PRODUCTCOMP').and_return true
      MasterSetup.any_instance.should_receive(:custom_feature?).with('Lumber EPD').and_return true
      expect(described_class.can_view?(u)).to be_true
    end
  end
  describe '#parse_xlsx' do
    it 'should send data to parse_row_arrays and call process_rows' do
      xlc = double(:xlclient)
      path = '/x/x/x'
      OpenChain::XLClient.should_receive(:new).with(path).and_return(xlc)
      row_vals = [['x','y']]
      row_structs = ['a','b']

      user_id = 10
      u = double(:user)
      User.should_receive(:find).with(10).and_return u
      
      error_messages_1 = ['msg1']
      error_messages_2 = ['msg2']
      
      xlc.should_receive(:all_row_values).with(0,1).and_return row_vals
      
      described_class.should_receive(:parse_row_arrays).with(row_vals).and_return [row_structs,error_messages_1]
      described_class.should_receive(:process_rows).with(row_structs,u).and_return(error_messages_2)
      described_class.should_receive(:write_results_message).with(u,['msg1','msg2'])

      described_class.parse_xlsx(path,user_id)
    end
  end
  describe '#parse_row_arrays' do
    it 'should return row structs' do
      rows = [0,1].collect do |row_num|
        r = Array.new(33)
        r[2] = "article_num_#{row_num}"
        r[3] = "variant_id_#{row_num}"
        r[7] = "vn_#{row_num}"
        r[11] = "component_#{row_num}"
        r[12] = "component_thickness_#{row_num}"
        r[26] = "genus_#{row_num}"
        r[27] = "species_#{row_num}"
        r[28] = "coo_#{row_num}"
        r
      end

      row_structs, errors = described_class.parse_row_arrays(rows)

      expect(row_structs).to have(2).structs
      expect(errors).to eq []

      row_structs.each_with_index do |rs,row_num|
        # left pad article number to 18 characters
        expect(rs.article_num).to eq "00000article_num_#{row_num}"
        expect(rs.variant_id).to eq "variant_id_#{row_num}"
        # left pad vendor number to 10 characters
        expect(rs.vendor_num).to eq "000000vn_#{row_num}"
        expect(rs.component).to eq "component_#{row_num}"
        expect(rs.component_thickness).to eq "component_thickness_#{row_num}"
        expect(rs.genus).to eq "genus_#{row_num}"
        expect(rs.species).to eq "species_#{row_num}"
        expect(rs.coo).to eq "coo_#{row_num}"
        expect(rs.row_num).to eq row_num+2
      end

    end
    it "should error if row.length > 0 & row.length not >= 33" do
      rows = [Array.new(33),Array.new(34),Array.new(0),Array.new(25)]
      structs, errors = described_class.parse_row_arrays(rows)
      expect(structs).to have(2).structs
      expect(errors).to eq ['Row 5 failed because it only has 25 columns. All rows must have at least 33 columns.']
    end
  end
  describe '#process_rows' do
    it 'should call process_variant for each unique variant group' do
      cdefs = described_class.prep_my_custom_definitions

      u = double('user')
      s_a_1_1 = @base_struct.new('a','1')
      s_a_1_2 = @base_struct.new('a','1')
      s_a_2 = @base_struct.new('a','2')
      s_b_1 = @base_struct.new('b','1')

      described_class.should_receive(:process_variant).with([s_a_1_1,s_a_1_2],u,cdefs).and_return nil
      described_class.should_receive(:process_variant).with([s_a_2],u,cdefs).and_return 'emsg'
      described_class.should_receive(:process_variant).with([s_b_1],u,cdefs).and_return 'emsg'
      
      #returns unique array of error messages
      expect(described_class.process_rows [s_a_1_1,s_a_2,s_b_1,s_a_1_2], u).to eq ['emsg']
    end
  end
  describe '#process_variant' do
    before :each do
      @u = Factory(:master_user)
      @cdefs = described_class.prep_my_custom_definitions
    end
    it "should create plant_variant_assignment" do
      Product.any_instance.should_receive(:create_snapshot)

      product = Factory(:product,unique_identifier:'000000000000000pid')
      var = Factory(:variant,variant_identifier:'varid',product:product)
      cmp = Factory(:company)
      cmp.update_custom_value!(@cdefs[:cmp_sap_company],'0000000123')
      plnt = Factory(:plant,company:cmp)

      s1 = @base_struct.new('000000000000000pid','varid','0000000123','base',1,'gen','spec','CN',2)
      s2 = @base_struct.new('000000000000000pid','varid','0000000123','top',11.3,'g2','s2','MX',2)

      errors = nil
      expect {errors = described_class.process_variant([s1,s2],@u,@cdefs)}.to change(PlantVariantAssignment,:count).from(0).to(1)

      expect(errors).to be_empty

      var.reload
      expect(Variant.all).to eq [var]
      expect(var.get_custom_value(@cdefs[:var_recipe]).value).to eq "base: gen/spec - 1 - CN\ntop: g2/s2 - 11.3 - MX"

      pva = PlantVariantAssignment.first
      expect(pva.plant).to eq plnt
      expect(pva.variant).to eq var
      expect(pva.get_custom_value(@cdefs[:pva_pc_approved_by]).value).to eq @u.id
      expect(pva.get_custom_value(@cdefs[:pva_pc_approved_date]).value).to_not be_nil
    end
    it "should not reset approvals" do
      product = Factory(:product,unique_identifier:'000000000000000pid')
      var = Factory(:variant,variant_identifier:'varid',product:product)
      cmp = Factory(:company)
      cmp.update_custom_value!(@cdefs[:cmp_sap_company],'0000000123')
      plnt = Factory(:plant,company:cmp)
      pva = plnt.plant_variant_assignments.create!(variant_id:var.id)
      expected_approved_date = 1.week.ago
      pva.update_custom_value!(@cdefs[:pva_pc_approved_date],expected_approved_date)
      u2 = Factory(:user)
      pva.update_custom_value!(@cdefs[:pva_pc_approved_by],u2.id)

      s1 = @base_struct.new('000000000000000pid','varid','0000000123','base',1,'gen','spec','CN',2)

      errors = nil
      expect {errors = described_class.process_variant([s1],@u,@cdefs)}.to_not change(PlantVariantAssignment,:count)

      expect(errors).to be_empty

      pva.reload

      expect(pva.get_custom_value(@cdefs[:pva_pc_approved_by]).value).to eq u2.id
      expect(pva.get_custom_value(@cdefs[:pva_pc_approved_date]).value.to_i).to eq expected_approved_date.to_i

    end
    it "should create variant if it doesn't exist" do
      product = Factory(:product,unique_identifier:'000000000000000pid')
      cmp = Factory(:company)
      cmp.update_custom_value!(@cdefs[:cmp_sap_company],'0000000123')
      plnt = Factory(:plant,company:cmp)

      s1 = @base_struct.new('000000000000000pid','varid','0000000123','base',1,'gen','spec','CN',2)
      s2 = @base_struct.new('000000000000000pid','varid','0000000123','top',11.3,'g2','s2','MX',2)

      errors = nil
      expect {errors = described_class.process_variant([s1,s2],@u,@cdefs)}.to change(PlantVariantAssignment,:count).from(0).to(1)

      expect(errors).to be_empty
      
      pva = PlantVariantAssignment.first
      var = pva.variant
      expect(var.get_custom_value(@cdefs[:var_recipe]).value).to eq "base: gen/spec - 1 - CN\ntop: g2/s2 - 11.3 - MX"
      expect(var.product).to eq product
      
    end
    it "should create plant if vendor exists and plant doesn't" do
      product = Factory(:product,unique_identifier:'000000000000000pid')
      var = Factory(:variant,variant_identifier:'varid',product:product)
      cmp = Factory(:company)
      cmp.update_custom_value!(@cdefs[:cmp_sap_company],'0000000123')
      
      s1 = @base_struct.new('000000000000000pid','varid','0000000123','base',1,'gen','spec','CN',2)

      errors = nil
      expect {errors = described_class.process_variant([s1],@u,@cdefs)}.to change(PlantVariantAssignment,:count).from(0).to(1)

      expect(errors).to be_empty

      pva = PlantVariantAssignment.first
      expect(pva.plant.company).to eq cmp
      expect(pva.variant).to eq var
      
    end
    it "should fail if product id is blank" do
      s1 = @base_struct.new('','varid','0000000123','base',1,'gen','spec','CN',2)

      errors = nil
      expect {errors = described_class.process_variant([s1],@u,@cdefs)}.to_not change(PlantVariantAssignment,:count)

      expect(errors).to eq ["Article number is blank for row 2."]
    end
    it "should fail if variant_identifier is blank" do
      s1 = @base_struct.new('000000000000000pid','','0000000123','base',1,'gen','spec','CN',2)

      errors = nil
      expect {errors = described_class.process_variant([s1],@u,@cdefs)}.to_not change(PlantVariantAssignment,:count)

      expect(errors).to eq ["Recipe ID is blank for row 2."]
    end
    it "should fail if vendor id is blank" do
      s1 = @base_struct.new('000000000000000pid','varid','','base',1,'gen','spec','CN',2)

      errors = nil
      expect {errors = described_class.process_variant([s1],@u,@cdefs)}.to_not change(PlantVariantAssignment,:count)

      expect(errors).to eq ["Vendor ID is blank for row 2."]
    end
    it "should fail if vendor doesn't exist" do
      product = Factory(:product,unique_identifier:'000000000000000pid')
      var = Factory(:variant,variant_identifier:'varid',product:product)
      
      s1 = @base_struct.new('000000000000000pid','varid','0000000123','base',1,'gen','spec','CN',2)

      errors = nil
      expect {errors = described_class.process_variant([s1],@u,@cdefs)}.to_not change(PlantVariantAssignment,:count)

      expect(errors).to eq ['Vendor "0000000123" not found for row 2.']
    end
    it "should fail if product doesn't exist" do
      cmp = Factory(:company)
      cmp.update_custom_value!(@cdefs[:cmp_sap_company],'0000000123')
      s1 = @base_struct.new('000000000000000pid','varid','0000000123','base',1,'gen','spec','CN',2)

      errors = nil
      expect {errors = described_class.process_variant([s1],@u,@cdefs)}.to_not change(PlantVariantAssignment,:count)

      expect(errors).to eq ['Product "000000000000000pid" not found for row 2.']
    end
  end
  describe '#write_results_message' do
    before :each do
      @u = Factory(:user)
    end
    it 'should write user message for success' do
      errors = []
      expect{described_class.write_results_message(@u,errors)}.to change(@u.messages,:count).from(0).to(1)

      msg = Message.first
      expect(msg.subject).to eq "EPD Processing Complete"
      expect(msg.body).to eq "<p>EPD Processing has finished.</p>"
    end
    it 'should write user message for failure' do
      errors = ["abc"]
      expect{described_class.write_results_message(@u,errors)}.to change(@u.messages,:count).from(0).to(1)

      msg = Message.first
      expect(msg.subject).to eq "EPD Processing Complete - WITH ERRORS"
      expect(msg.body).to match /abc/

    end
  end
end