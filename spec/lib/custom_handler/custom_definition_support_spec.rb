describe OpenChain::CustomHandler::CustomDefinitionSupport do

  subject {
    Class.new do
      extend OpenChain::CustomHandler::CustomDefinitionSupport
    end
  }

  describe '#prep_custom_defs' do

    it "finds existing custom definitions" do
      cd = FactoryBot(:custom_definition, cdef_uid:'XYZ', label:'abc', module_type:'Order', data_type: :string)

      h = {cdef_uid:'XYZ', label:'OTHER', module_type: 'Order', data_type: 'string'}
      defs = subject.prep_custom_defs [:my_field], {my_field: h}

      expect(defs[:my_field]).to eq cd
    end

    it "will not create a new definition without a cdef_uid" do
      expect {
        defs = subject.prep_custom_defs [:my_field], {my_field: {label:'abc', module_type: 'Order', data_type: 'string'}}
      }.to raise_error "All new Custom Definitions should contain cdef_uid identifiers. Order field 'abc' did not have an identifier."
    end

    it "should find when cdef_uid is same and label is different" do
      cd = FactoryBot(:custom_definition, cdef_uid:'XYZ', label:'abc', module_type:'Order', data_type: :string)
      expect {
        defs = subject.prep_custom_defs [:my_field], {my_field: {cdef_uid:'XYZ', label:'OTHER', module_type: cd.module_type, data_type: cd.data_type}}
        expect(defs[:my_field]).to eq cd
      }.to_not change(CustomDefinition, :count)
    end

    it "should create a new definition with a cdef_uid" do
      expect(Lock).to receive(:acquire).with("CustomDefinition-XYZ", {yield_in_transaction: false}).and_yield

      defs = nil
      h = {cdef_uid:'XYZ', label:'OTHER', module_type: 'Order', data_type: 'string'}
      expect {
        defs = subject.prep_custom_defs [:my_field], {my_field: h}
      }.to change(CustomDefinition, :count).by(1)
      cd = defs[:my_field]
      expect(cd.cdef_uid).to eq h[:cdef_uid]
      expect(cd.label).to eq h[:label]
      expect(cd.module_type).to eq h[:module_type]
      expect(cd.data_type).to eq h[:data_type]
      expect(cd.id).to be > 0
    end

    it "creates a read_only field validator rule" do
      cd = subject.prep_custom_defs([:my_field], {my_field: {cdef_uid:'XYZ', label:'OTHER', module_type: 'Order', data_type: 'string', read_only: true}})[:my_field]

      rule = FieldValidatorRule.where(custom_definition_id: cd.id).first
      expect(rule).not_to be_nil
      expect(rule.read_only?).to eq true
    end

    it "errors if definition hash is missing a field" do
      expect { subject.prep_custom_defs [:my_field], {} }.to raise_error "No custom definition setup found for field identifier: my_field."
    end
  end
end
