describe Classification do
  describe 'classified?' do
    before :each do
      @c = Factory(:classification)
    end
    it "should return true for classified classification" do
      @c.tariff_records.create!(:hts_1=>'12345678')
      expect(@c).to be_classified
    end
    it "should return false if no tariff records" do
      expect(@c).not_to be_classified
    end
    it "should return false if tariff records don't have HTS" do
      @c.tariff_records.create!
      expect(@c).not_to be_classified
    end
  end
  describe 'find_same' do
    it 'should return nil when no matches' do
      c = Factory(:classification)
      expect(c.find_same).to be_nil
    end
    it 'should return the match when there is one' do
      c = Factory(:classification)
      new_one = Classification.new(:product_id=>c.product_id,:country_id=>c.country_id)
      expect(new_one.find_same).to eq(c)
    end
    it 'should ignore instant_classification children for matching purposes' do
      c = Factory(:classification,:instant_classification_id=>1)
      new_one = Classification.new(:product_id=>c.product_id,:country_id=>c.country_id)
      expect(new_one.find_same).to be_nil
    end
  end

  describe "reject_nested_model_field_attributes_if" do
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

    it 'rejects model_field attributes unless specific values are present' do
      @c.update_model_field_attributes! @params
      expect(@c.tariff_records.size).to eq(0)
    end

    it 'does not reject when hts values are present' do
      @params[:tariff_records_attributes]['0'][:hts_hts_1] = "1"
      @c.update_model_field_attributes! @params
      expect(@c.tariff_records.size).to eq(1)
    end

    it "does not reject updates with no tariff numbers if id is present" do
      @params[:tariff_records_attributes]['0'][:id] = "1"
      t = @c.tariff_records.create! hts_1: "1234567890"

      @params[:tariff_records_attributes]['0'][:id] = t.id
      @params[:tariff_records_attributes]['0'][:hts_line_number] = 5
      @c.update_model_field_attributes! @params

      expect(@c.tariff_records.first.line_number).to eq 5
    end
  end
end
