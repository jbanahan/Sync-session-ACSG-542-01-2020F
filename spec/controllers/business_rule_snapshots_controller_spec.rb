require 'spec_helper'

describe BusinessRuleSnapshotsController do

  let! (:entity) { Factory(:entry, broker_reference: "REF") }
  let (:user) { Factory(:user) }

  before :each do
    sign_in_as user
  end

  describe "index" do
    it "lists all rule comparisons for an object" do
      Entry.any_instance.stub(:can_view?).with(user).and_return true
      user.stub(:view_business_validation_results?).and_return true

      comparisons = [{"key" => "val"}]
      BusinessRuleSnapshot.should_receive(:rule_comparisons).with(instance_of(Entry)).and_return comparisons

      get :index, {recordable_type: "entries", recordable_id: entity.id}
      expect(response).not_to be_redirect
      expect(assigns(:object)).to eq entity
      expect(assigns(:object_type)).to eq "Entry"
      expect(assigns(:object_key)).to eq "REF"
      expect(assigns(:rule_comparisons)).to eq comparisons
      expect(assigns(:back_path)).to eq "/entries/#{entity.id}/validation_results"
    end

    it "redirects with error if user can't view entity" do
      Entry.any_instance.stub(:can_view?).with(user).and_return false
      get :index, {recordable_type: "entries", recordable_id: entity.id}
      expect(response).to be_redirect
      expect(flash[:errors]).to include "You do not have permission to view these business rules."
    end

    it "redirects with error if user can't view validation results" do
      Entry.any_instance.stub(:can_view?).with(user).and_return true
      user.stub(:view_business_validation_results?).and_return false
      get :index, {recordable_type: "entries", recordable_id: entity.id}
      expect(response).to be_redirect
      expect(flash[:errors]).to include "You do not have permission to view these business rules."
    end
  end
end