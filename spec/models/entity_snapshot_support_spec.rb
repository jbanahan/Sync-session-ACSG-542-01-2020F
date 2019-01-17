describe EntitySnapshotSupport do 
  # Use an object we know includes the EntitySnapshotSupport and destroys snapshots
  subject { Order.new }

  describe "async_destroy_snapshots" do 

    it "calls async_destroy_snapshots w/ correct object identifier parameters" do
      expect(MasterSetup).to receive(:production_env?).and_return false
      expect(subject).to receive(:id).and_return 1
      expect(subject.class).to receive(:destroy_snapshots).with(1, "Order")

      subject.async_destroy_snapshots
    end

    it "delays snapshot destroy in prod" do
      expect(MasterSetup).to receive(:production_env?).and_return true
      expect(subject).to receive(:id).and_return 1
      expect(subject.class).to receive(:delay).with({priority: 100}).and_return subject.class
      expect(subject.class).to receive(:destroy_snapshots).with(1, "Order")      

      subject.async_destroy_snapshots
    end

    it "does not delay destroy_snapshots if object's core module does not return true for destroy_snapshots" do
      cm = instance_double(CoreModule)
      expect(CoreModule).to receive(:find_by_object).with(subject).and_return cm
      expect(cm).to receive(:destroy_snapshots).and_return false
      expect(subject.class).not_to receive(:destroy_snapshots)

      subject.async_destroy_snapshots
    end
  end

  describe "destroy_snapshots" do
    let (:user) { Factory(:user) }
    let (:entity_snapshot) { subject.entity_snapshots.create! user_id: user.id, doc_path: "entity_path" }
    let (:business_rule_snapshot) { subject.business_rule_snapshots.create! doc_path: "rule_path"}

    before :each do 
      subject.update_attributes! order_number: "ORD", importer: Factory(:importer)
      entity_snapshot
      business_rule_snapshot
    end

    it "copies all snapshots to deleted bucket and the destroys them" do
      expect_any_instance_of(EntitySnapshot).to receive(:copy_to_deleted_bucket) do |instance|
        expect(instance).to eq entity_snapshot
        true
      end

      expect_any_instance_of(BusinessRuleSnapshot).to receive(:copy_to_deleted_bucket) do |instance|
        expect(instance).to eq business_rule_snapshot
        true
      end

      expect(subject.class.destroy_snapshots subject.id, "Order").to eq true

      # make sure the rules are destroyed
      expect(entity_snapshot).not_to exist_in_db
      expect(business_rule_snapshot).not_to exist_in_db
    end

    it "marks snapshots as deleted once they're moved" do 
      expect_any_instance_of(EntitySnapshot).to receive(:copy_to_deleted_bucket) do |instance|
        expect(instance).to eq entity_snapshot
        true
      end

      expect_any_instance_of(BusinessRuleSnapshot).to receive(:copy_to_deleted_bucket) do |instance|
        expect(instance).to eq business_rule_snapshot
        false
      end

      expect{ subject.class.destroy_snapshots subject.id, "Order" }.to raise_error "Failed to copy BusinessRuleSnapshot #{business_rule_snapshot.id} to deleted bucket."

      expect(entity_snapshot).to exist_in_db
      entity_snapshot.reload
      expect(entity_snapshot.doc_path).to be_nil
      expect(entity_snapshot.bucket).to be_nil
      expect(entity_snapshot.version).to be_nil
    end
    
    it "does not attempt to move snapshots that don't have doc_paths" do
      entity_snapshot.update_attributes! doc_path: nil
      business_rule_snapshot.update_attributes! doc_path: nil

      expect_any_instance_of(EntitySnapshot).not_to receive(:copy_to_deleted_bucket)
      expect_any_instance_of(BusinessRuleSnapshot).not_to receive(:copy_to_deleted_bucket)

      expect(subject.class.destroy_snapshots subject.id, "Order").to eq true

      # make sure the rules were destroyed
      expect(entity_snapshot).not_to exist_in_db
      expect(business_rule_snapshot).not_to exist_in_db
    end
  end
end