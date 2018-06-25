module ConfigMigrations; module Common; class CompanyYoyReportSow1487

  def up
    Group.use_system_group 'company_yoy_report', name: 'Company Year Over Year Report', description: 'Users permitted to run a report comparing office entry data by month/year.', create: true
    generate_data_cross_references
  end

  def down
    Group.where(system_code:'company_yoy_report').destroy_all
    DataCrossReference.where(cross_reference_type: DataCrossReference::VFI_DIVISION).destroy_all
  end

  def generate_data_cross_references
    DataCrossReference.where(cross_reference_type: DataCrossReference::VFI_DIVISION, key:'0001', value:'Clark').first_or_create!
    DataCrossReference.where(cross_reference_type: DataCrossReference::VFI_DIVISION, key:'0002', value:'JFK').first_or_create!
    DataCrossReference.where(cross_reference_type: DataCrossReference::VFI_DIVISION, key:'0004', value:'Long Beach').first_or_create!
    # No longer an active division but included because YoY report that uses these may be run over older data.
    DataCrossReference.where(cross_reference_type: DataCrossReference::VFI_DIVISION, key:'0006', value:'Norfolk').first_or_create!
    DataCrossReference.where(cross_reference_type: DataCrossReference::VFI_DIVISION, key:'0007', value:'San Francisco').first_or_create!
    DataCrossReference.where(cross_reference_type: DataCrossReference::VFI_DIVISION, key:'0008', value:'Chicago').first_or_create!
    DataCrossReference.where(cross_reference_type: DataCrossReference::VFI_DIVISION, key:'0009', value:'Boston').first_or_create!
    DataCrossReference.where(cross_reference_type: DataCrossReference::VFI_DIVISION, key:'0010', value:'Baltimore').first_or_create!
    DataCrossReference.where(cross_reference_type: DataCrossReference::VFI_DIVISION, key:'0015', value:'Columbus').first_or_create!
    DataCrossReference.where(cross_reference_type: DataCrossReference::VFI_DIVISION, key:'0016', value:'Ft. Lauderdale').first_or_create!
    DataCrossReference.where(cross_reference_type: DataCrossReference::VFI_DIVISION, key:'0017', value:'Pembina').first_or_create!
  end

end; end; end