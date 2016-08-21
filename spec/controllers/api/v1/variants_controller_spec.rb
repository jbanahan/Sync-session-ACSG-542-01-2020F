require 'spec_helper'

describe Api::V1::VariantsController do
  before :each do
    @u = Factory(:user)
    allow_api_access @u
  end
  describe '#show' do
    before :each do
      @v = Factory(:variant,variant_identifier:'v123')
    end
    it 'should show if user can view variant' do
      expect_any_instance_of(Variant).to receive(:can_view?).with(@u).and_return true
      get :show, id: @v.id
      expect(response).to be_success

      h = JSON.parse(response.body)['variant']
      expect(h['var_identifier']).to eq @v.variant_identifier
    end
    it 'should not show if users cannot view variant' do
      expect_any_instance_of(Variant).to receive(:can_view?).with(@u).and_return false
      get :show, id: @v.id
      expect(response.status).to eq 404
    end
  end
end