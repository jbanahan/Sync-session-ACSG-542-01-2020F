require 'spec_helper'

describe OpenChain::CustomHandler::Pepsi::PepsiQuakerProductApprovalResetComparator do
  before :each do
    # in test we have to reset the custom definition constant on every run so it doesn't cache
    # old, invalid custom definition IDs.  This isn't an issue on production or development.
    described_class::CUSTOM_DEFINITIONS.clear
  end
  describe '#compare' do
    it 'should ignore non-products' do
      described_class.should_not_receive(:get_json_hash)
      described_class.compare 'Order', 10, 'ob', 'op', 'ov', 'nb', 'np', 'nv'
    end
    it 'should ignore new products' do
      described_class.should_not_receive(:get_json_hash)
      described_class.compare 'Product', 10, nil, nil, nil, 'nb', 'np', 'nv'
    end
    it 'should get hashes and call compare_hashes' do
      h1 = double('hash1')
      h2 = double('hash2')
      described_class.should_receive(:get_json_hash).with('ob','op','ov').and_return(h1)
      described_class.should_receive(:get_json_hash).with('nb','np','nv').and_return(h2)
      described_class.should_receive(:compare_hashes).with(10,h1,h2)
      described_class.compare 'Product', 10, 'ob', 'op', 'ov', 'nb', 'np', 'nv'
    end
  end

  describe 'compare_hashes' do
    it 'should fingerprint both hashes and call reset if different' do
      h1 = double('hash1')
      h2 = double('hash2')
      [h1,h2].each_with_index {|h,idx| described_class.should_receive(:fingerprint).with(h).and_return(idx.to_s)}
      described_class.should_receive(:reset).with(10)
      described_class.compare_hashes(10,h1,h2)
    end
    it 'should fingerprint both hashes and not call reset if different' do
      h1 = double('hash1')
      h2 = double('hash2')
      [h1,h2].each {|h| described_class.should_receive(:fingerprint).with(h).and_return('a')}
      described_class.should_not_receive(:reset)
      described_class.compare_hashes(10,h1,h2)
    end
  end

  describe 'fingerprint' do
    it 'should make fingerprint' do
      prod_cdef_keys = [:prod_shipper_name, :prod_prod_code, :prod_us_broker, :prod_us_alt_broker, :prod_alt_prod_code,
        :prod_coo, :prod_tcsa, :prod_recod, :prod_first_sale, :prod_related, :prod_fda_pn, :prod_fda_uom_1, :prod_fda_uom_2,
        :prod_fda_fce, :prod_fda_sid, :prod_fda_dims, :prod_oga_1, :prod_oga_2, :prod_prog_code, :prod_proc_code, :prod_indented_use,
        :prod_trade_name, :prod_cbp_mid, :prod_fda_mid,:prod_base_customs_description, :prod_fda_code, :prod_fda_reg, :prod_fdc, :prod_fda_desc]
      classification_cdef_keys = [
        :class_add_cvd, :class_fta_end, :class_fta_start, :class_fta_notes, :class_fta_name,
        :class_ior, :class_tariff_shift, :class_val_content, :class_ruling_number, :class_customs_desc_override
      ]
      cdefs = described_class.prep_custom_definitions(prod_cdef_keys + classification_cdef_keys)
      p = Factory(:product,unique_identifier:'uid')
      expected = {
        'prod_uid'=>'uid',
        'classifications'=>{}
      }
      prod_cdef_keys.each do |k|
        cd = cdefs[k]
        val = case (cd.data_type)
          when :boolean
            true
          when :date
            Date.new(2010,1,1)
          when :datetime
            Time.new(2010,12,25,11,15,30)
          else
            k.to_s
        end
        p.update_custom_value!(cd,val)
        expected[k.to_s] = (cd.data_type==:boolean ? val : val.to_s)
      end
      us = Factory(:country,iso_code:'US')
      ca = Factory(:country,iso_code:'CA')

      us_class = Factory(:classification,country:us,product:p)
      ca_class = Factory(:classification,country:ca,product:p)

      [us_class,ca_class].each do |cls|
        iso = cls.country.iso_code
        expected['classifications'][iso] = {}
        classification_cdef_keys.each do |k|
          cd = cdefs[k]
          val = case (cd.data_type)
            when :boolean
              true
            when :date
              Date.new(2010,1,1)
            when :datetime
              Time.new(2010,12,25,11,15,30)
            else
              k.to_s
          end
          cls.update_custom_value!(cd,val)
          expected['classifications'][iso][k.to_s] = (cd.data_type==:boolean ? val : val.to_s)
        end

        Factory(:tariff_record,hts_1:'1234567890',line_number:1,classification:cls)
        expected['classifications'][iso]['tariff_records'] = {}
        expected['classifications'][iso]['tariff_records']['1'] = {'hts_hts_1'=>'1234567890'.hts_format}
      end

      p.reload
      es = p.create_snapshot(Factory(:user))

      fp = described_class.fingerprint(es.snapshot_hash)
      fp_h = JSON.parse(fp)

      expect(fp_h).to eq expected
    end
  end


  describe 'reset' do
    it 'should reset pepsi quaker approved by and approved date' do
      Product.any_instance.should_receive(:create_snapshot)
      p = Factory(:product)
      cdefs = described_class.prep_custom_definitions([:prod_quaker_validated_by,:prod_quaker_validated_date])
      p.update_custom_value!(cdefs[:prod_quaker_validated_by],100)
      p.update_custom_value!(cdefs[:prod_quaker_validated_date],Time.now)

      described_class.reset(p.id)

      p.reload

      [:prod_quaker_validated_by,:prod_quaker_validated_date].each do |k|
        expect(p.get_custom_value(cdefs[k]).value).to be_blank
      end
    end
  end
end
