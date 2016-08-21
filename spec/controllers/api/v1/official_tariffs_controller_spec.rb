require 'spec_helper'

describe Api::V1::OfficialTariffsController do
  before :each do
    @user = Factory(:user)
    allow_api_access @user
  end

  describe :find do
    it "should render tariff" do
      allow_any_instance_of(OfficialTariff).to receive(:can_view?).and_return true
      us = Factory(:country,iso_code:'US',name:'USA')
      ot = Factory(:official_tariff,
        hts_code:'1234567890',
        full_description:'Full Desc',
        special_rates:'NAFTA:0',
        general_rate:'10',
        chapter:'Hinnies',
        heading:'Mule',
        sub_heading:'Ass',
        remaining_description:'RD',
        add_valorem_rate:'14',
        per_unit_rate:'12',
        calculation_method:'1',
        most_favored_nation_rate:'13',
        general_preferential_tariff_rate:'11',
        erga_omnes_rate:'1.1',
        unit_of_measure:'KG',
        column_2_rate:'c2',
        import_regulations:'IR',
        export_regulations:'ER',
        common_rate:'CR',
        country:us
        )
      other_ot = Factory(:official_tariff)
      allow_any_instance_of(OfficialTariff).to receive(:binding_ruling_url).and_return 'abc'
      allow_any_instance_of(OfficialTariff).to receive(:taric_url).and_return 'tar'

      expected_response = {'official_tariff'=>{
        'id'=>ot.id,
        'ot_hts_code'=>'1234.56.7890',
        'ot_full_desc'=>ot.full_description,
        'ot_spec_rates'=>ot.special_rates,
        'ot_gen_rate'=>ot.general_rate,
        'ot_chapter'=>ot.chapter,
        'ot_heading'=>ot.heading,
        'ot_sub_heading'=>ot.sub_heading,
        'ot_remaining'=>ot.remaining_description,
        'ot_ad_v'=>ot.add_valorem_rate,
        'ot_per_u'=>ot.per_unit_rate,
        'ot_calc_meth'=>ot.calculation_method,
        'ot_mfn'=>ot.most_favored_nation_rate,
        'ot_gpt'=>ot.general_preferential_tariff_rate,
        'ot_erga_omnes_rate'=>ot.erga_omnes_rate,
        'ot_uom'=>ot.unit_of_measure,
        'ot_col_2'=>ot.column_2_rate,
        'ot_import_regs'=>ot.import_regulations,
        'ot_export_regs'=>ot.export_regulations,
        'ot_common_rate'=>ot.common_rate,
        'ot_binding_ruling_url'=>'abc',
        'ot_taric_url'=>'tar'
      }}


      expect(get :find, {iso:'us',hts:'1234567890'}).to be_success

      expect(JSON.parse(response.body)).to eq expected_response
    end
    it "should strip periods" do
      allow_any_instance_of(OfficialTariff).to receive(:can_view?).and_return true
      us = Factory(:country,iso_code:'US',name:'USA')
      ot = Factory(:official_tariff,country:us,hts_code:'1234567890')
      
      expect(get :find, {iso:'us',hts:'1234.56.7890'}).to be_success
      expect(JSON.parse(response.body)['official_tariff']['id']).to eq ot.id         
    end
  end
end