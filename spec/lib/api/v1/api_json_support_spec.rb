describe OpenChain::Api::V1::ApiJsonSupport do
  let (:jsonize) { double("OpenChain::Api::ApiEntityJsonizer") }
  let (:user) { User.new username: "test" }
  let (:object) { Order.new order_number: "Order" }

  subject {
    Class.new do
      include OpenChain::Api::V1::ApiJsonSupport

      def initialize(jsonize)
        super(jsonizer: jsonize)
      end

      def params 
        raise "Mock me"
      end

      def current_user
        raise "Mock me"
      end
    end.new(jsonize)
  }

  describe "to_entity_hash" do
    it "proxies call to the underlying jsonizer" do
      expect(jsonize).to receive(:entity_to_hash).with(user, object, ['fld_test', 'fld_test_2'])

      subject.to_entity_hash(object, [:fld_test, :fld_test_2], user: user)
    end

    it "uses current_user if user is not given as keyword arg" do
      expect(subject).to receive(:current_user).and_return user
      expect(jsonize).to receive(:entity_to_hash).with(user, object, ['fld_test', 'fld_test_2'])

      subject.to_entity_hash(object, [:fld_test, :fld_test_2])
    end
  end

  describe "export_field" do
    it "proxies call to underlying jsonizer" do
      expect(jsonize).to receive(:export_field).with(user, object, ModelField.find_by_uid(:prod_uid))

      subject.export_field :prod_uid, object, user: user
    end

    it "uses current_user if user is not given as keyword arg" do
      expect(subject).to receive(:current_user).and_return user
      expect(jsonize).to receive(:export_field).with(user, object, ModelField.find_by_uid(:prod_uid))

      subject.export_field :prod_uid, object
    end
  end

  describe "requested_field_list" do
    it "extracts model field list from params" do
      expect(subject.requested_field_list http_params: {fields: "a, b, c"}).to eq ["a", "b", "c"]
    end

    it "extracts model field list from params using tilde" do
      expect(subject.requested_field_list http_params: {fields: "a~b~c"}).to eq ["a", "b", "c"]
    end

    it "extracts model field list from params using fallback parameter naming" do
      expect(subject.requested_field_list http_params: {mf_uids: "a, b, c"}).to eq ["a", "b", "c"]
    end

    it "handles arrays as params" do
      expect(subject.requested_field_list http_params: {fields: ["a", "b", "c"]}).to eq ["a", "b", "c"]
    end

    it "returns blank array if no params found" do
      expect(subject.requested_field_list http_params: {params: ["a", "b", "c"]}).to eq []
    end

    it "uses params method if http_params are not supplied" do
      expect(subject).to receive(:params).and_return({fields: ["a", "b", "c"]})
      expect(subject.requested_field_list).to eq ["a", "b", "c"]
    end
  end

  describe "limit_fields" do
    it "returns intersection of fields provided and fields requested by user from params" do
      expect(subject.limit_fields [:prod_uid, :prod_name], user: user, http_params: {fields: ["prod_uid"]}).to eq [:prod_uid]
    end

    it "returns all fields if no fields are requested by user" do
      expect(subject.limit_fields [:prod_uid, :prod_name], user: user, http_params: {}).to eq [:prod_uid, :prod_name]
    end

    it "strips all fields that user does not have access to" do
      expect(ModelField.find_by_uid(:prod_uid)).to receive(:can_view?).with(user).and_return true
      expect(ModelField.find_by_uid(:prod_name)).to receive(:can_view?).with(user).and_return false

      expect(subject.limit_fields [:prod_uid, :prod_name], user: user, http_params: {}).to eq [:prod_uid]
    end

    it "uses params method and current_user method when neither are supplied" do
      expect(subject).to receive(:params).and_return({fields: ["prod_uid"]})
      expect(subject).to receive(:current_user).and_return user

      expect(subject.limit_fields [:prod_uid, :prod_name]).to eq [:prod_uid]
    end
  end

  describe "all_requested_model_fields" do
    it "returns all the core model fields" do
      fields = subject.all_requested_model_fields CoreModule::FOLDER, user: user, http_params: {}
      expect(fields.size).to eq(CoreModule::FOLDER.model_fields(user, true).size)
      # Just make sure a model field we know to be a folder field is actually in the list
      expect(fields).to include ModelField.find_by_uid(:fld_name)
    end

    it "returns all core model fields and those requested from child associations" do
      fields = subject.all_requested_model_fields CoreModule::FOLDER, user: user, http_params: {include: "comments, groups"}, associations: {'comments' => CoreModule::COMMENT, 'groups' => CoreModule::GROUP}
      expect(fields.size).to eq (CoreModule::FOLDER.model_fields(user, true).size + CoreModule::COMMENT.model_fields(user, true).size + CoreModule::GROUP.model_fields(user, true).size)

      # Just make sure a model field we know to be a folder field is actually in the list
      expect(fields).to include ModelField.find_by_uid(:fld_name)
      expect(fields).to include ModelField.find_by_uid(:cmt_subject)
      expect(fields).to include ModelField.find_by_uid(:grp_name)
    end

    it "does not return fields for those that are not requested in params" do
      fields = subject.all_requested_model_fields CoreModule::FOLDER, user: user, http_params: {include: "comments"}, associations: {'comments' => CoreModule::COMMENT, 'groups' => CoreModule::GROUP}
      expect(fields.size).to eq (CoreModule::FOLDER.model_fields(user, true).size + CoreModule::COMMENT.model_fields(user, true).size)

      # Just make sure a model field we know to be a folder field is actually in the list
      expect(fields).to include ModelField.find_by_uid(:fld_name)
      expect(fields).to include ModelField.find_by_uid(:cmt_subject)
      expect(fields).not_to include ModelField.find_by_uid(:grp_name)
    end

    it "does not return fields that user cannot see" do
      allow_any_instance_of(ModelField).to receive(:can_view?).with(user).and_return false
      fields = subject.all_requested_model_fields CoreModule::FOLDER, user: user, http_params: {}
      expect(fields.size).to eq 0
    end
  end

end