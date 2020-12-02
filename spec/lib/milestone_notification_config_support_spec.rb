describe OpenChain::MilestoneNotificationConfigSupport do

  let(:klass) do
    Class.new do
      include OpenChain::MilestoneNotificationConfigSupport
    end.new
  end
  let(:user) { create(:sys_admin_user) }
  let(:mf1) { ModelField.by_uid "ent_release_date" }
  let(:mf2) { ModelField.by_uid "ent_duty_due_date" }
  let(:mf3) { ModelField.by_uid "ent_cust_num"}

  before do
    allow(ModelField).to receive(:find_by_module_type).with(CoreModule::ENTRY).and_return([mf1, mf2, mf3])
  end

  describe "instance methods" do

    describe "event_list" do
      before do
        DataCrossReference.create! cross_reference_type: "tradelens_entry_milestone_fields", key: "ent_release_date", value: "release"
        DataCrossReference.create! cross_reference_type: "tradelens_entry_milestone_fields", key: "ent_filed_date", value: "filed"
      end

      it "returns data from date/datetime model fields sorted by label" do
        list = klass.event_list user, "Entry"
        expect(list).to eq [{field_name: "duty_due_date",
                             mfid: "ent_duty_due_date",
                             label: "Duty Due Date (duty_due_date) - Date",
                             datatype: "date",
                             filters: []},
                            {field_name: "release_date",
                             mfid: "ent_release_date",
                             label: "Release Date (release_date) - Datetime",
                             datatype: "datetime",
                             filters: ["tradelens"]}]
      end
    end
  end

  describe "DataCrossReferenceKeySelector" do
    it "takes output of event_list and returns label/mfid tuples suitable for xref edit view" do
      allowed_keys = described_class::DataCrossReferenceKeySelector.new "Entry"
      expect(allowed_keys.to_a).to eq [["Duty Due Date (duty_due_date) - Date", "ent_duty_due_date"],
                                       ["Release Date (release_date) - Datetime", "ent_release_date"]]
    end
  end

  describe "DataCrossReferenceValueSelector" do
    it "takes endpoint data from Entry315TradelensGenerator and returns tuples for xref edit view" do
      expect(OpenChain::CustomHandler::Generator315::Tradelens::Entry315TradelensGenerator).to receive(:entry_endpoint_labels).and_return({customs_release: "Customs Release"})
      allowed_values = described_class::DataCrossReferenceValueSelector.new "Entry"
      expect(allowed_values.to_a).to eq [["Customs Release", :customs_release]]
    end
  end

end
