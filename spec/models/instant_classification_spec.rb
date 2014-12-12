require 'spec_helper'

describe InstantClassification do
  describe "find by product" do
    before :each do
      @first_ic = InstantClassification.create!(:name=>'bulk test',:rank=>1)
      @first_ic.search_criterions.create!(:model_field_uid=>'prod_uid',:operator=>'sw',:value=>'bulk')
      @second_ic = InstantClassification.create!(:name=>'bulk test 2',:rank=>2) #should match this one
      @second_ic.search_criterions.create!(:model_field_uid=>'prod_uid',:operator=>'eq',:value=>'findme')
      @third_ic = InstantClassification.create!(:name=>'bulk test 3',:rank=>3) #this one would match, but we shouldn't hit it because second_ic will match first
      @third_ic.search_criterions.create!(:model_field_uid=>'prod_uid',:operator=>'ew',:value=>'me')
    end
    it "should find a match" do
      p = Factory(:product,:unique_identifier=>'findme')
      InstantClassification.find_by_product(p,Factory(:user)).should == @second_ic
    end
    it "should not find a match" do
      p = Factory(:product,:unique_identifier=>'dont')
      InstantClassification.find_by_product(p,Factory(:user)).should be_nil
    end
  end
  describe "test" do
    before :each do
      @ic = InstantClassification.create!(:name=>"ic1")
      @ic.search_criterions.create!(:model_field_uid=>'prod_uid',:operator=>'eq',:value=>'puidict')
    end
    it "should match" do
      @ic.test?(Factory(:product,:unique_identifier=>'puidict'),Factory(:user)).should be_true 
    end
    it "shouldn't match" do
      @ic.test?(Factory(:product,:unique_identifier=>'not puidict'),Factory(:user)).should be_false 
    end
  end

  describe "update_model_field_attributes" do
    before :each do
      @country = Factory(:country)
      @class_cd = Factory(:custom_definition, :module_type=>'Classification',:data_type=>:decimal)
      @tariff_cd = Factory(:custom_definition, :module_type=>'TariffRecord',:data_type=>:date)
    end

    it "creates child classification / tariff records from params" do
      params = {
        'classifications_attributes' => {'0' => {
          'class_cntry_iso' => @country.iso_code,
          @class_cd.model_field_uid => '12.3',
          'tariff_records_attributes' => {'0' => {
            'hts_line_number' => '1',
            'hts_hts_1' => '1234.56.7890',
            @tariff_cd.model_field_uid => '2014-12-01'
            }}
        }}
      }

      ic = InstantClassification.new name: "Test"
      expect(ic.update_model_field_attributes! params).to be_true

      expect(ic.classifications.length).to eq 1
      expect(ic.classifications.first.country).to eq @country
      expect(ic.classifications.first.get_custom_value(@class_cd).value).to eq 12.3
      expect(ic.classifications.first.tariff_records.length).to eq 1
      expect(ic.classifications.first.tariff_records.first.hts_1).to eq "1234567890"
      expect(ic.classifications.first.tariff_records.first.get_custom_value(@tariff_cd).value).to eq Date.new(2014, 12, 1)
    end

    it "updates classification / tariff records from params" do
      ic = InstantClassification.create! name: "Test"
      cl = ic.classifications.create! country_id: @country.id
      tr = cl.tariff_records.create! hts_1: '1234.56.7890'

      params = {
        'classifications_attributes' => {'0' => {
          'id' => cl.id,
          @class_cd.model_field_uid => '12.3',
          'tariff_records_attributes' => {'0' => {
            'id' => tr.id,
            @tariff_cd.model_field_uid => '2014-12-01'
            }}
        }}
      }

      expect(ic.update_model_field_attributes! params).to be_true

      expect(ic.classifications.length).to eq 1
      expect(ic.classifications.first.get_custom_value(@class_cd).value).to eq 12.3
      expect(ic.classifications.first.tariff_records.length).to eq 1
      expect(ic.classifications.first.tariff_records.first.get_custom_value(@tariff_cd).value).to eq Date.new(2014, 12, 1)
    end
  end
end
