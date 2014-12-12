require 'spec_helper'

describe Classification do
  describe 'classified?' do
    before :each do
      @c = Factory(:classification)
    end
    it "should return true for classified classification" do
      @c.tariff_records.create!(:hts_1=>'12345678')
      @c.should be_classified
    end
    it "should return false if no tariff records" do
      @c.should_not be_classified
    end
    it "should return false if tariff records don't have HTS" do
      @c.tariff_records.create!
      @c.should_not be_classified
    end
  end
  describe 'find_same' do
    it 'should return nil when no matches' do
      c = Factory(:classification)
      c.find_same.should be_nil
    end
    it 'should return the match when there is one' do
      c = Factory(:classification)
      new_one = Classification.new(:product_id=>c.product_id,:country_id=>c.country_id)
      new_one.find_same.should == c
    end
    it 'should ignore instant_classification children for matching purposes' do
      c = Factory(:classification,:instant_classification_id=>1)
      new_one = Classification.new(:product_id=>c.product_id,:country_id=>c.country_id)
      new_one.find_same.should be_nil
    end
  end

  describe "accepts_nested_attributes_for tariff_records" do
    before :each do
      @c = Factory(:classification)
      @params = {
        tariff_records_attributes: {
            '0' => {
              line_number: 1,
              view_sequence: 1
            }
         }
      }
    end

    it 'rejects attributes unless specific values are present' do
      fail "Need to make this validation work with new update_model_field_attributes process"
      @c.update_attributes! @params
      @c.tariff_records.should have(0).items
    end

    it 'does not reject when hts 1 values are present' do
      @params[:tariff_records_attributes]['0'][:hts_1] = "1"
      @c.update_attributes! @params
      @c.tariff_records.should have(1).item
    end

    it 'does not reject when hts 2 values are present' do
      @params[:tariff_records_attributes]['0'][:hts_2] = "1"
      @c.update_attributes! @params
      @c.tariff_records.should have(1).item
    end

    it 'does not reject when hts 3 values are present' do
      @params[:tariff_records_attributes]['0'][:hts_3] = "1"
      @c.update_attributes! @params
      @c.tariff_records.should have(1).item
    end

    it 'does not reject when schedule b 1 values are present' do
      @params[:tariff_records_attributes]['0'][:schedule_b_1] = "1"
      @c.update_attributes! @params
      @c.tariff_records.should have(1).item
    end

    it 'does not reject when schedule b 2 values are present' do
      @params[:tariff_records_attributes]['0'][:schedule_b_2] = "1"
      @c.update_attributes! @params
      @c.tariff_records.should have(1).item
    end

    it 'does not reject when schedule b 3 values are present' do
      @params[:tariff_records_attributes]['0'][:schedule_b_3] = "1"
      @c.update_attributes! @params
      @c.tariff_records.should have(1).item
    end

    it 'does not reject when no values are present for destroys' do
      r = @c.tariff_records.create! :hts_1 => "1"
      @params[:tariff_records_attributes]['0'][:id] = r.id
      @params[:tariff_records_attributes]['0'][:_destroy] = "true"
      @c.update_attributes! @params
      @c.tariff_records.should have(0).items
    end

    it "rejects on false destroys when no values are present" do
      @params[:tariff_records_attributes]['0'][:_destroy] = "false"

      @c.update_attributes! @params
      @c.tariff_records.should have(0).items
    end
  end
end
