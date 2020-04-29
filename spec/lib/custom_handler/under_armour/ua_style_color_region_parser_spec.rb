describe OpenChain::CustomHandler::UnderArmour::UaStyleColorRegionParser do
  before :each do
    @cf = double('custom_file')
  end
  let :new_parser do
    described_class.new(@cf)
  end
  describe '#can_view?' do
    before :each do
      @u = User.new
      @u.company = Company.new
      @u.company.master = true
      allow(@u).to receive(:edit_trade_preference_programs?).and_return true
      allow(@u).to receive(:edit_variants?).and_return true
      allow_any_instance_of(MasterSetup).to receive(:custom_feature?).and_return true
    end
    it 'should be visible if user from master company and can edit_trade_preference_programs? && edit_variants? and UA-TPP custom feature' do
      expect(new_parser.can_view?(@u)).to be_truthy
    end
    context 'not visible' do
      after :each do
        expect(new_parser.can_view?(@u)).to be_falsey
      end
      it 'if not master company' do
        @u.company.master = false
      end
      it 'if not edit_trade_preference_programs?' do
        allow(@u).to receive(:edit_trade_preference_programs?).and_return false
      end
      it 'if not edit_variants' do
        allow(@u).to receive(:edit_variants?).and_return false
      end
      it 'if not custom feature' do
        expect_any_instance_of(MasterSetup).to receive(:custom_feature?).with('UA-TPP').and_return false
      end

    end
  end
  describe '#process' do
    it 'should collect_rows and pass to update_data_hash and then process_data_hash' do
      u = Factory(:user)
      parser = new_parser
      expect(parser).to receive(:can_view?).with(u).and_return true
      expect(parser).to receive(:collect_rows).and_yield 'cr'
      expect(parser).to receive(:update_data_hash).with(instance_of(Hash), 'cr')
      expect(parser).to receive(:process_data_hash).with(instance_of(Hash), u)
      parser.process(u)
      u.reload
      expect(u.messages.first.subject).to eq "Style/Color/Region Parser Complete"
    end
    it 'should fail if user cannot view' do
      u = Factory(:user)
      parser = new_parser
      expect(parser).to receive(:can_view?).with(u).and_return false
      expect {parser.process(u)}.to raise_error(/permission/)
    end
  end

  describe 'collect_rows' do
    it 'should get rows from API' do
      r = []
      xlc = double('xl_client')
      expect(OpenChain::XLClient).to receive(:new_from_attachable).with(@cf).and_return xlc
      expect(xlc).to receive(:all_row_values).with(chunk_size: 500).and_yield('a').and_yield('b')
      new_parser.collect_rows {|row| r << row}
      expect(r).to eq ['a', 'b']
    end
  end

  describe '#update_data_hash' do
    before :each do
      @h = Hash.new
    end
    let :row do
      ['1234567', 'Style Name', '1234567-001', 'Style-CLR', 'Apparel', 'FW17', 'MEXICO']
    end
    it 'should skip rows that do not have 7 elements' do
      new_parser.update_data_hash(@h, ['a'])
      expect(@h).to be_empty
    end
    it 'should skip rows where the first element == Style' do
      r = row
      r[0] = 'Style'
      new_parser.update_data_hash(@h, r)
      expect(@h).to be_empty
    end
    it 'should fail if a row has 7 elements and column a is not a 7 digit number' do
      r = row
      r[0] = '12'
      expect {new_parser.update_data_hash(@h, r)}.to raise_error(/Style .* must be a 7 digit number/)
    end
    it 'should fail on bad region name' do
      r = row
      r[6] = 'OTHERREGION'
      expect {new_parser.update_data_hash(@h, r)}.to raise_error(/OTHERREGION/)
    end
    it 'should append to existing style' do
      r = row
      @h = {'1234567'=>{name:'a', colors:{'999'=>['US'], '001'=>['US']}, division:'X', seasons:['SS15']}}
      new_parser.update_data_hash(@h, r)
      expected = {'1234567'=>
        {style:'1234567', name:'Style Name', colors:{'999'=>['US'], '001'=>['US', 'MX']}, division:'Apparel', seasons:['SS15', 'FW17']}
      }
      expect(@h).to eq expected
    end
    it 'should create style' do
      r = row
      new_parser.update_data_hash(@h, r)
      expected = {'1234567'=>
        {style:'1234567', name:'Style Name', colors:{'001'=>['MX']}, division:'Apparel', seasons:['FW17']}
      }
      expect(@h).to eq expected
    end
    it 'should skip if color has a letter' do
      r = row
      r[2] = '1234567-S01'
      new_parser.update_data_hash(@h, r)
      expect(@h['1234567'][:colors]).to be_empty
    end
  end

  describe '#process_data_hash' do
    it 'should call update_product for each style' do
      u = double('user')
      a = double('a')
      b = double('b')
      h = {'1234567'=>a, '7891234'=>b}
      p = new_parser
      expect(p).to receive(:update_product).with(a, u)
      expect(p).to receive(:update_product).with(b, u)
      p.process_data_hash h, u
    end
  end
  describe '#update_product' do
    let :hash do
      {
        style:'1234567',
        name:'My Name',
        colors:{'001'=>['MX', 'AU'], '002'=>['MX']},
        division:'Apparel',
        seasons:['SS15', 'FW17']
      }
    end
    let :user do
      allow_any_instance_of(Product).to receive(:can_edit?).and_return true
      allow_any_instance_of(Variant).to receive(:can_edit?).and_return true
      Factory(:master_user)
    end
    let :custom_defs do
      described_class.prep_custom_definitions [
        :prod_seasons,
        :colors,
        :prod_import_countries,
        :var_import_countries
      ]
    end
    it 'should create new style and division' do
      cdefs = custom_defs
      expect {new_parser.update_product(hash, user)}.to change(Product, :count).from(0).to(1)
      p = Product.first
      expect(p.name).to eq 'My Name'
      expect(p.unique_identifier).to eq '1234567'
      expect(p.division.name).to eq 'Apparel'
      expect(p.entity_snapshots.count).to eq 1
      expect(p.get_custom_value(cdefs[:prod_seasons]).value).to eq "FW17\nSS15"
      expect(p.get_custom_value(cdefs[:colors]).value).to eq "001\n002"
      expect(p.get_custom_value(cdefs[:prod_import_countries]).value).to eq "AU\nMX"
      expect(p.variants.count).to eq 2
      v = p.variants.find_by variant_identifier:  '001'
      expect(v.get_custom_value(cdefs[:var_import_countries]).value).to eq "AU\nMX"
      v2 = p.variants.find_by variant_identifier:  '002'
      expect(v2.get_custom_value(cdefs[:var_import_countries]).value).to eq "MX"
    end
    it 'should update existing style' do
      cdefs = custom_defs
      p = Factory(:product, name:'somename', unique_identifier:'1234567')
      p.update_custom_value!(cdefs[:prod_seasons], "FW17\nSS17")
      v = Factory(:variant, product:p, variant_identifier:'001')
      expect {new_parser.update_product(hash, user)}.to_not change(Product, :count)
      p = Product.first
      expect(p.name).to eq 'My Name'
      expect(p.get_custom_value(cdefs[:prod_seasons]).value).to eq "FW17\nSS15\nSS17"
      expect(p.variants.count).to eq 2
      v = p.variants.find_by variant_identifier:  '001'
      expect(v.get_custom_value(cdefs[:var_import_countries]).value).to eq "AU\nMX"
      v2 = p.variants.find_by variant_identifier:  '002'
      expect(v2.get_custom_value(cdefs[:var_import_countries]).value).to eq "MX"
    end
  end
end
