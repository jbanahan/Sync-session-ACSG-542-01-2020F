module ConfigMigrations; module Www; class MaerskCargowiseSow1664

  def up
    generate_data_cross_references
    nil
  end

  def down
    drop_data_cross_references
    nil
  end

  private
    def generate_data_cross_references
      DataCrossReference.where(cross_reference_type: DataCrossReference::CARGOWISE_TRANSPORT_MODE_US, key:'06', value:'11').first_or_create!
      DataCrossReference.where(cross_reference_type: DataCrossReference::CARGOWISE_TRANSPORT_MODE_US, key:'AIR', value:'40').first_or_create!
      DataCrossReference.where(cross_reference_type: DataCrossReference::CARGOWISE_TRANSPORT_MODE_US, key:'AIR00', value:'40').first_or_create!
      DataCrossReference.where(cross_reference_type: DataCrossReference::CARGOWISE_TRANSPORT_MODE_US, key:'AIR006', value:'40').first_or_create!
      DataCrossReference.where(cross_reference_type: DataCrossReference::CARGOWISE_TRANSPORT_MODE_US, key:'AIR01', value:'40').first_or_create!
      DataCrossReference.where(cross_reference_type: DataCrossReference::CARGOWISE_TRANSPORT_MODE_US, key:'AIR016', value:'40').first_or_create!
      DataCrossReference.where(cross_reference_type: DataCrossReference::CARGOWISE_TRANSPORT_MODE_US, key:'AIR01N', value:'40').first_or_create!
      DataCrossReference.where(cross_reference_type: DataCrossReference::CARGOWISE_TRANSPORT_MODE_US, key:'AIR112', value:'40').first_or_create!
      DataCrossReference.where(cross_reference_type: DataCrossReference::CARGOWISE_TRANSPORT_MODE_US, key:'AIR160', value:'40').first_or_create!
      DataCrossReference.where(cross_reference_type: DataCrossReference::CARGOWISE_TRANSPORT_MODE_US, key:'AIR235', value:'40').first_or_create!
      DataCrossReference.where(cross_reference_type: DataCrossReference::CARGOWISE_TRANSPORT_MODE_US, key:'AIR297', value:'1').first_or_create!
      DataCrossReference.where(cross_reference_type: DataCrossReference::CARGOWISE_TRANSPORT_MODE_US, key:'AIR40', value:'40').first_or_create!
      DataCrossReference.where(cross_reference_type: DataCrossReference::CARGOWISE_TRANSPORT_MODE_US, key:'AIR69', value:'1').first_or_create!
      DataCrossReference.where(cross_reference_type: DataCrossReference::CARGOWISE_TRANSPORT_MODE_US, key:'AIR695', value:'40').first_or_create!
      DataCrossReference.where(cross_reference_type: DataCrossReference::CARGOWISE_TRANSPORT_MODE_US, key:'AIR933', value:'1').first_or_create!
      DataCrossReference.where(cross_reference_type: DataCrossReference::CARGOWISE_TRANSPORT_MODE_US, key:'AIRBBK', value:'40').first_or_create!
      DataCrossReference.where(cross_reference_type: DataCrossReference::CARGOWISE_TRANSPORT_MODE_US, key:'AIRBKK', value:'40').first_or_create!
      DataCrossReference.where(cross_reference_type: DataCrossReference::CARGOWISE_TRANSPORT_MODE_US, key:'AIRBLK', value:'40').first_or_create!
      DataCrossReference.where(cross_reference_type: DataCrossReference::CARGOWISE_TRANSPORT_MODE_US, key:'AIRCNT', value:'41').first_or_create!
      DataCrossReference.where(cross_reference_type: DataCrossReference::CARGOWISE_TRANSPORT_MODE_US, key:'AIRCTN', value:'40').first_or_create!
      DataCrossReference.where(cross_reference_type: DataCrossReference::CARGOWISE_TRANSPORT_MODE_US, key:'AIRLQD', value:'40').first_or_create!
      DataCrossReference.where(cross_reference_type: DataCrossReference::CARGOWISE_TRANSPORT_MODE_US, key:'AIRNCC', value:'40').first_or_create!
      DataCrossReference.where(cross_reference_type: DataCrossReference::CARGOWISE_TRANSPORT_MODE_US, key:'AIRNCF', value:'40').first_or_create!
      DataCrossReference.where(cross_reference_type: DataCrossReference::CARGOWISE_TRANSPORT_MODE_US, key:'AIRNCR', value:'40').first_or_create!
      DataCrossReference.where(cross_reference_type: DataCrossReference::CARGOWISE_TRANSPORT_MODE_US, key:'AIRNCT', value:'40').first_or_create!
      DataCrossReference.where(cross_reference_type: DataCrossReference::CARGOWISE_TRANSPORT_MODE_US, key:'AIRNCV', value:'40').first_or_create!
      DataCrossReference.where(cross_reference_type: DataCrossReference::CARGOWISE_TRANSPORT_MODE_US, key:'AIRNON', value:'40').first_or_create!
      DataCrossReference.where(cross_reference_type: DataCrossReference::CARGOWISE_TRANSPORT_MODE_US, key:'AIRNRT', value:'40').first_or_create!
      DataCrossReference.where(cross_reference_type: DataCrossReference::CARGOWISE_TRANSPORT_MODE_US, key:'AIRPO', value:'40').first_or_create!
      DataCrossReference.where(cross_reference_type: DataCrossReference::CARGOWISE_TRANSPORT_MODE_US, key:'AIRSEA', value:'40').first_or_create!
      DataCrossReference.where(cross_reference_type: DataCrossReference::CARGOWISE_TRANSPORT_MODE_US, key:'AIRUS5', value:'40').first_or_create!
      DataCrossReference.where(cross_reference_type: DataCrossReference::CARGOWISE_TRANSPORT_MODE_US, key:'CNT', value:'11').first_or_create!
      DataCrossReference.where(cross_reference_type: DataCrossReference::CARGOWISE_TRANSPORT_MODE_US, key:'PHC', value:'60').first_or_create!
      DataCrossReference.where(cross_reference_type: DataCrossReference::CARGOWISE_TRANSPORT_MODE_US, key:'RAI', value:'20').first_or_create!
      DataCrossReference.where(cross_reference_type: DataCrossReference::CARGOWISE_TRANSPORT_MODE_US, key:'RAIBBK', value:'20').first_or_create!
      DataCrossReference.where(cross_reference_type: DataCrossReference::CARGOWISE_TRANSPORT_MODE_US, key:'RAIBLK', value:'20').first_or_create!
      DataCrossReference.where(cross_reference_type: DataCrossReference::CARGOWISE_TRANSPORT_MODE_US, key:'RAICNT', value:'21').first_or_create!
      DataCrossReference.where(cross_reference_type: DataCrossReference::CARGOWISE_TRANSPORT_MODE_US, key:'RAICTN', value:'21').first_or_create!
      DataCrossReference.where(cross_reference_type: DataCrossReference::CARGOWISE_TRANSPORT_MODE_US, key:'RAILQD', value:'20').first_or_create!
      DataCrossReference.where(cross_reference_type: DataCrossReference::CARGOWISE_TRANSPORT_MODE_US, key:'RAINCT', value:'20').first_or_create!
      DataCrossReference.where(cross_reference_type: DataCrossReference::CARGOWISE_TRANSPORT_MODE_US, key:'ROA', value:'34').first_or_create!
      DataCrossReference.where(cross_reference_type: DataCrossReference::CARGOWISE_TRANSPORT_MODE_US, key:'SEA', value:'11').first_or_create!
      DataCrossReference.where(cross_reference_type: DataCrossReference::CARGOWISE_TRANSPORT_MODE_US, key:'SEA01', value:'11').first_or_create!
      DataCrossReference.where(cross_reference_type: DataCrossReference::CARGOWISE_TRANSPORT_MODE_US, key:'SEABBK', value:'10').first_or_create!
      DataCrossReference.where(cross_reference_type: DataCrossReference::CARGOWISE_TRANSPORT_MODE_US, key:'SEABLK', value:'10').first_or_create!
      DataCrossReference.where(cross_reference_type: DataCrossReference::CARGOWISE_TRANSPORT_MODE_US, key:'SEACNT', value:'11').first_or_create!
      DataCrossReference.where(cross_reference_type: DataCrossReference::CARGOWISE_TRANSPORT_MODE_US, key:'SEACT', value:'11').first_or_create!
      DataCrossReference.where(cross_reference_type: DataCrossReference::CARGOWISE_TRANSPORT_MODE_US, key:'SEACTN', value:'11').first_or_create!
      DataCrossReference.where(cross_reference_type: DataCrossReference::CARGOWISE_TRANSPORT_MODE_US, key:'SEALQD', value:'10').first_or_create!
      DataCrossReference.where(cross_reference_type: DataCrossReference::CARGOWISE_TRANSPORT_MODE_US, key:'SEANCT', value:'10').first_or_create!
      DataCrossReference.where(cross_reference_type: DataCrossReference::CARGOWISE_TRANSPORT_MODE_US, key:'SEARAI', value:'6').first_or_create!
      DataCrossReference.where(cross_reference_type: DataCrossReference::CARGOWISE_TRANSPORT_MODE_US, key:'SEATRK', value:'10').first_or_create!
      DataCrossReference.where(cross_reference_type: DataCrossReference::CARGOWISE_TRANSPORT_MODE_US, key:'TRK', value:'30').first_or_create!
      DataCrossReference.where(cross_reference_type: DataCrossReference::CARGOWISE_TRANSPORT_MODE_US, key:'TRKBBK', value:'30').first_or_create!
      DataCrossReference.where(cross_reference_type: DataCrossReference::CARGOWISE_TRANSPORT_MODE_US, key:'TRKBLK', value:'30').first_or_create!
      DataCrossReference.where(cross_reference_type: DataCrossReference::CARGOWISE_TRANSPORT_MODE_US, key:'TRKCNT', value:'31').first_or_create!
      DataCrossReference.where(cross_reference_type: DataCrossReference::CARGOWISE_TRANSPORT_MODE_US, key:'TRKLQD', value:'30').first_or_create!
      DataCrossReference.where(cross_reference_type: DataCrossReference::CARGOWISE_TRANSPORT_MODE_US, key:'TRKNCT', value:'30').first_or_create!

      DataCrossReference.where(cross_reference_type: DataCrossReference::CARGOWISE_TRANSPORT_MODE_CA, key:'AIR', value:'1').first_or_create!
      DataCrossReference.where(cross_reference_type: DataCrossReference::CARGOWISE_TRANSPORT_MODE_CA, key:'AIR69', value:'1').first_or_create!
      DataCrossReference.where(cross_reference_type: DataCrossReference::CARGOWISE_TRANSPORT_MODE_CA, key:'AIR695', value:'1').first_or_create!
      DataCrossReference.where(cross_reference_type: DataCrossReference::CARGOWISE_TRANSPORT_MODE_CA, key:'AIR933', value:'1').first_or_create!
      DataCrossReference.where(cross_reference_type: DataCrossReference::CARGOWISE_TRANSPORT_MODE_CA, key:'CNT', value:'9').first_or_create!
      DataCrossReference.where(cross_reference_type: DataCrossReference::CARGOWISE_TRANSPORT_MODE_CA, key:'CTN', value:'9').first_or_create!
      DataCrossReference.where(cross_reference_type: DataCrossReference::CARGOWISE_TRANSPORT_MODE_CA, key:'NOC', value:'8').first_or_create!
      DataCrossReference.where(cross_reference_type: DataCrossReference::CARGOWISE_TRANSPORT_MODE_CA, key:'OTH', value:'9').first_or_create!
      DataCrossReference.where(cross_reference_type: DataCrossReference::CARGOWISE_TRANSPORT_MODE_CA, key:'PIP', value:'7').first_or_create!
      DataCrossReference.where(cross_reference_type: DataCrossReference::CARGOWISE_TRANSPORT_MODE_CA, key:'RAI', value:'6').first_or_create!
      DataCrossReference.where(cross_reference_type: DataCrossReference::CARGOWISE_TRANSPORT_MODE_CA, key:'RAIBBK', value:'6').first_or_create!
      DataCrossReference.where(cross_reference_type: DataCrossReference::CARGOWISE_TRANSPORT_MODE_CA, key:'RAIBLK', value:'6').first_or_create!
      DataCrossReference.where(cross_reference_type: DataCrossReference::CARGOWISE_TRANSPORT_MODE_CA, key:'RAICNT', value:'6').first_or_create!
      DataCrossReference.where(cross_reference_type: DataCrossReference::CARGOWISE_TRANSPORT_MODE_CA, key:'RAICTN', value:'6').first_or_create!
      DataCrossReference.where(cross_reference_type: DataCrossReference::CARGOWISE_TRANSPORT_MODE_CA, key:'RAILQD', value:'6').first_or_create!
      DataCrossReference.where(cross_reference_type: DataCrossReference::CARGOWISE_TRANSPORT_MODE_CA, key:'ROA', value:'2').first_or_create!
      DataCrossReference.where(cross_reference_type: DataCrossReference::CARGOWISE_TRANSPORT_MODE_CA, key:'ROA270', value:'2').first_or_create!
      DataCrossReference.where(cross_reference_type: DataCrossReference::CARGOWISE_TRANSPORT_MODE_CA, key:'ROABBK', value:'2').first_or_create!
      DataCrossReference.where(cross_reference_type: DataCrossReference::CARGOWISE_TRANSPORT_MODE_CA, key:'ROABLK', value:'2').first_or_create!
      DataCrossReference.where(cross_reference_type: DataCrossReference::CARGOWISE_TRANSPORT_MODE_CA, key:'ROACNT', value:'2').first_or_create!
      DataCrossReference.where(cross_reference_type: DataCrossReference::CARGOWISE_TRANSPORT_MODE_CA, key:'ROACTN', value:'2').first_or_create!
      DataCrossReference.where(cross_reference_type: DataCrossReference::CARGOWISE_TRANSPORT_MODE_CA, key:'ROALQD', value:'2').first_or_create!
      DataCrossReference.where(cross_reference_type: DataCrossReference::CARGOWISE_TRANSPORT_MODE_CA, key:'SEA', value:'9').first_or_create!
      DataCrossReference.where(cross_reference_type: DataCrossReference::CARGOWISE_TRANSPORT_MODE_CA, key:'SEA125', value:'10').first_or_create!
      DataCrossReference.where(cross_reference_type: DataCrossReference::CARGOWISE_TRANSPORT_MODE_CA, key:'SEABBK', value:'9').first_or_create!
      DataCrossReference.where(cross_reference_type: DataCrossReference::CARGOWISE_TRANSPORT_MODE_CA, key:'SEABLK', value:'9').first_or_create!
      DataCrossReference.where(cross_reference_type: DataCrossReference::CARGOWISE_TRANSPORT_MODE_CA, key:'SEACNT', value:'9').first_or_create!
      DataCrossReference.where(cross_reference_type: DataCrossReference::CARGOWISE_TRANSPORT_MODE_CA, key:'SEACT', value:'11').first_or_create!
      DataCrossReference.where(cross_reference_type: DataCrossReference::CARGOWISE_TRANSPORT_MODE_CA, key:'SEACTN', value:'9').first_or_create!
      DataCrossReference.where(cross_reference_type: DataCrossReference::CARGOWISE_TRANSPORT_MODE_CA, key:'SEAHYU', value:'9').first_or_create!
      DataCrossReference.where(cross_reference_type: DataCrossReference::CARGOWISE_TRANSPORT_MODE_CA, key:'SEALQD', value:'9').first_or_create!
    end

    def drop_data_cross_references
      DataCrossReference.where(cross_reference_type: DataCrossReference::CARGOWISE_TRANSPORT_MODE_US).destroy_all
      DataCrossReference.where(cross_reference_type: DataCrossReference::CARGOWISE_TRANSPORT_MODE_CA).destroy_all
    end

end; end; end