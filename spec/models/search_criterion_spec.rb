require 'spec_helper'

describe SearchCriterion do
  before :each do 
    @product = Factory(:product)
  end
  context 'boolean custom field' do
    before :each do
      @definition = Factory(:custom_definition,:data_type=>'boolean')
      @custom_value = @product.get_custom_value @definition
    end
    context 'Is Empty' do
      before :each do
        @search_criterion = SearchCriterion.create!(
          :model_field_uid=>"*cf_#{@definition.id}",
          :operator => "null",
          :value => ''
        )
      end
      it 'should return for Is Empty and false' do
        @custom_value.value = false
        @custom_value.save!
        @search_criterion.apply(Product).should include @product 
        @search_criterion.passes?(@custom_value.value).should == true
      end
      it 'should return for Is Empty and nil' do
        @custom_value.value = nil
        @custom_value.save!
        @search_criterion.apply(Product).should include @product 
        @search_criterion.passes?(@custom_value.value).should == true
      end

      it 'should not return for Is Empty and true' do
        @custom_value.value = true
        @custom_value.save!
        @search_criterion.apply(Product).should_not include @product 
        @search_criterion.passes?(@custom_value.value).should == false
      end

    end
    context 'Is Not Empty' do
      before :each do
        @search_criterion = SearchCriterion.create!(
          :model_field_uid=>"*cf_#{@definition.id}",
          :operator => "notnull",
          :value => ''
        )
      end
      it 'should return for Is Not Empty and true' do
        @custom_value.value = true
        @custom_value.save!
        @search_criterion.apply(Product).should include @product 
        @search_criterion.passes?(@custom_value.value).should == true
      end

      it 'should not return for Is Not Empty and false' do
        @custom_value.value = false
        @custom_value.save!
        @search_criterion.apply(Product).should_not include @product 
        @search_criterion.passes?(@custom_value.value).should == false
      end

      it 'should not return for Is Not Empty and nil' do
        @custom_value.value = nil
        @custom_value.save!
        @search_criterion.apply(Product).should_not include @product 
        @search_criterion.passes?(@custom_value.value).should == false
      end

    end
  end
end
