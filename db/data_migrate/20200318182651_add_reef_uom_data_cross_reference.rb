class AddReefUomDataCrossReference < ActiveRecord::Migration
  def up
    if Company.with_customs_management_number("REEF").first
      DataCrossReference.where(cross_reference_type: DataCrossReference::UNIT_OF_MEASURE, key:'PR', value:'PRS', company: Company.with_customs_management_number("REEF").first).first_or_create!
    end
  end

  def down
    DataCrossReference.where(cross_reference_type: DataCrossReference::UNIT_OF_MEASURE, key:'PR', value:'PRS', company: Company.with_customs_management_number("REEF").first).destroy_all!
  end
end
