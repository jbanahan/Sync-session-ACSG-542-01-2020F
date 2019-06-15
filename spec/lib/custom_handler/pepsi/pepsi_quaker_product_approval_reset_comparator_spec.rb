describe OpenChain::CustomHandler::Pepsi::PepsiQuakerProductApprovalResetComparator do
  before :all do 
    described_class.new.cdefs
    described_class.new.reset_cdefs
  end

  after :all do 
    CustomDefinition.destroy_all
  end

  describe '#compare' do
    subject { described_class }

    it 'should ignore new products' do
      expect(subject).not_to receive(:get_json_hash)
      subject.compare 'Product', 10, nil, nil, nil, 'nb', 'np', 'nv'
    end
    it 'should get hashes and call compare_hashes' do
      h1 = double('hash1')
      h2 = double('hash2')
      expect(subject).to receive(:get_json_hash).with('ob','op','ov').and_return(h1)
      expect(subject).to receive(:get_json_hash).with('nb','np','nv').and_return(h2)
      expect_any_instance_of(subject).to receive(:compare_hashes).with(10,h1,h2)
      subject.compare 'Product', 10, 'ob', 'op', 'ov', 'nb', 'np', 'nv'
    end
  end

  describe 'compare_hashes' do
    let (:cdefs) { 
      subject.cdefs
    }

    it 'should fingerprint both hashes and call reset if different' do
      h1 = double('hash1')
      h2 = double('hash2')
      [h1,h2].each_with_index {|h,idx| expect(subject).to receive(:fingerprint).with(h).and_return(idx.to_s)}
      expect(subject).to receive(:reset).with(10)
      subject.compare_hashes(10,h1,h2)
    end
    it 'should fingerprint both hashes and not call reset if different' do
      h1 = double('hash1')
      h2 = double('hash2')
      [h1,h2].each {|h| expect(subject).to receive(:fingerprint).with(h).and_return('a')}
      expect(subject).not_to receive(:reset)
      subject.compare_hashes(10,h1,h2)
    end
  end

  describe 'fingerprint', :snapshot do
    let (:cdefs) { 
      subject.cdefs
    }

    it 'should make fingerprint' do
      prod_cdef_keys = [:prod_shipper_name, :prod_prod_code, :prod_us_broker, :prod_us_alt_broker, :prod_alt_prod_code,
        :prod_coo, :prod_tcsa, :prod_recod, :prod_first_sale, :prod_related, :prod_fda_pn, :prod_fda_uom_1, :prod_fda_uom_2,
        :prod_fda_fce, :prod_fda_sid, :prod_fda_dims, :prod_oga_1, :prod_oga_2, :prod_prog_code, :prod_proc_code, :prod_indented_use,
        :prod_trade_name, :prod_cbp_mid, :prod_fda_mid,:prod_base_customs_description, :prod_fda_code, :prod_fda_reg, :prod_fdc, :prod_fda_desc]
      classification_cdef_keys = [
        :class_add_cvd, :class_fta_end, :class_fta_start, :class_fta_notes, :class_fta_name,
        :class_ior, :class_tariff_shift, :class_val_content, :class_ruling_number, :class_customs_desc_override
      ]
      p = Factory(:product,unique_identifier:'uid')
      expected = {
        'prod_uid'=>'uid',
        'classifications'=>{}
      }
      prod_cdef_keys.each do |k|
        cd = cdefs[k]
        val = case (cd.data_type.to_sym)
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
        expected[k.to_s] = (cd.data_type=="boolean" ? val : val.to_s)
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
          val = case (cd.data_type.to_sym)
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
          expected['classifications'][iso][k.to_s] = (cd.data_type=="boolean" ? val : val.to_s)
        end

        Factory(:tariff_record,hts_1:'1234567890',line_number:1,classification:cls)
        expected['classifications'][iso]['tariff_records'] = {}
        expected['classifications'][iso]['tariff_records']['1'] = {'hts_hts_1'=>'1234567890'.hts_format}
      end

      p.reload
      es = p.create_snapshot(Factory(:user))

      fp = subject.fingerprint(es.snapshot_hash)
      fp_h = JSON.parse(fp)

      expect(fp_h).to eq expected
    end
  end


  describe 'reset' do
    let (:cdefs) { 
      subject.reset_cdefs
    }

    it 'should reset pepsi quaker approved by and approved date' do
      expect_any_instance_of(Product).to receive(:create_snapshot)
      p = Factory(:product)
      p.update_custom_value!(cdefs[:prod_quaker_validated_by],100)
      p.update_custom_value!(cdefs[:prod_quaker_validated_date],Time.now)

      subject.reset(p.id)

      p.reload

      [:prod_quaker_validated_by,:prod_quaker_validated_date].each do |k|
        expect(p.custom_value(cdefs[k])).to be_blank
      end
    end
  end
end
