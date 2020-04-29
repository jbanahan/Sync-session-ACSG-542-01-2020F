describe Api::V1::ApiController do

  describe '#allow_csv' do
    let :setup_route do
      u = Factory(:user)
      allow_api_user u
    end
    context 'allows_csv' do
      controller(Api::V1::ApiController) do
        prepend_before_filter :allow_csv
        def index
          respond_to do |format|
            format.csv {render text: 'hello'}
          end
        end
      end
      it 'should allow csv if before_filter is set' do
        setup_route
        get :index, format: :csv
        expect(response.body).to eq 'hello'
      end
    end
    context 'no_csv' do
      controller(Api::V1::ApiController) do
        def index
          respond_to do |format|
            format.csv {render text: 'hello'}
          end
        end
      end
      it 'should not allow csv if before_filter is not set' do
        setup_route
        get :index, format: :csv
        expect(response).to_not be_success
      end
    end
  end

  describe "model_field_reload" do
    controller do
      def index
        render json: {ok: 'ok'}
      end
    end
    it "should reload stale model fields" do
      u = Factory(:user)
      allow_api_access u
      expect(ModelField).to receive(:reload_if_stale)
      get :index
      expect(response).to be_success
      expect(ModelField.disable_stale_checks).to be_truthy
    end
  end

  describe "action_secure" do
    controller do
      def index
        obj = Company.first
        action_secure(params[:permission_check], obj, {lock_check: params[:lock_check]}) { render json: {notice: "Block yielded!"} }
      end
    end

    before :each do
      @obj = Factory(:company)
      u = Factory(:user)
      allow_api_access u
    end

    it "returns error if permission check fails" do
      post :index, permission_check: false, lock_check: false
      expect(JSON.parse response.body).to eq({"errors" => ["You do not have permission to edit this object."]})
    end

    context "permission check passes" do
      it "returns error if object is locked" do
        @obj.locked = true; @obj.save!
        post :index, permission_check: true, lock_check: true
        expect(JSON.parse response.body).to eq({"errors" => ["You cannot edit an object with a locked company."]})
      end

      it "yields if object isn't locked" do
        post :index, permission_check: true, lock_check: true
        expect(JSON.parse response.body).to eq({"notice" => "Block yielded!"})
      end

      it "yields if lock-check is disabled" do
        @obj.locked = true; @obj.save!
        post :index, permission_check: true, lock_check: false
        expect(JSON.parse response.body).to eq({"notice" => "Block yielded!"})
      end
    end

  end

  describe "render_ok" do
    it "renders an ok response" do
      expect(subject).to receive(:render).with(json: {ok: "ok"})
      subject.render_ok
    end
  end

  describe "model_field_reload" do
    let! (:ms) {
      stub_master_setup
    }

    controller do
      def index
        render json: {ok: 'ok'}
      end
    end

    it "sets MasterSetup.current" do
      u = Factory(:user)
      allow_api_access u

      get :index
      expect(response).to be_success
      expect(MasterSetup.current).to eq ms
    end
  end

  describe "action_secure" do

    it "checks permission and fails if permission check returns false" do
      expect(subject).to receive(:render_forbidden).with("You do not have permission to edit this object.")
      subject.action_secure(false, nil)
    end

    it "yields if permission check is true" do
      expect(subject).not_to receive(:render_forbidden)
      yielded = false
      subject.action_secure(true, nil) { yielded = true }
      expect(yielded).to eq true
    end

    it "yields in db_lock if request is a mutable request type" do
      allow(request).to receive(:get?).and_return false
      object = Factory(:product)

      expect(Lock).to receive(:db_lock).with(object).and_yield
      yielded = false
      subject.action_secure(true, object) { yielded = true }
      expect(yielded).to eq true
    end

    it "does not yield in db_lock if request is a nonmutable request type" do
      expect(request).to receive(:get?).and_return true
      object = Factory(:product)

      expect(Lock).not_to receive(:db_lock)
      yielded = false
      subject.action_secure(true, object) { yielded = true }
      expect(yielded).to eq true
    end

    it "yields in db_lock if request is a nonmutable request type if forced" do
      expect(request).to receive(:get?).and_return true
      object = Factory(:product)

      expect(Lock).to receive(:db_lock).with(object).and_yield
      yielded = false
      subject.action_secure(true, object, yield_in_db_lock: true) { yielded = true }
      expect(yielded).to eq true
    end

    it "does not yield in db_lock if object is not an ActiveRecord object" do
      expect(Lock).not_to receive(:db_lock)
      yielded = false
      subject.action_secure(true, "", yield_in_db_lock: true) { yielded = true }
      expect(yielded).to eq true
    end

    it "does not yield in db_lock if object is not persisted" do
      expect(Lock).not_to receive(:db_lock)
      yielded = false
      subject.action_secure(true, Product.new, yield_in_db_lock: true) { yielded = true }
      expect(yielded).to eq true
    end

    it "checks for locked objects" do
      p = Product.new
      expect(p).to receive(:locked?).and_return true
      expect(subject).to receive(:render_forbidden).with "You cannot edit an object with a locked company."
      yielded = false
      subject.action_secure(true, p) { yielded = true }
      expect(yielded).to eq false
    end

    it "allows replacing default lock lambda" do
      p = Product.new
      expect(p).not_to receive(:locked?)
      expect(subject).not_to receive(:render_forbidden)
      yielded = false
      subject.action_secure(true, p, {lock_lambda: lambda {|o| false} }) { yielded = true }
      expect(yielded).to eq true
    end

    it "allows bypassing lock check" do
      lock_check = false
      lock_lambda = lambda { |o| lock_check = true }
      yielded = false
      subject.action_secure(true, p, lock_check: false) { yielded = true }
      expect(yielded).to eq true
    end

    it "allows passing new module name" do
      p = Product.new
      expect(p).to receive(:locked?).and_return true
      expect(subject).to receive(:render_forbidden).with "You cannot edit a My Product with a locked company."
      yielded = false
      subject.action_secure(true, p, module_name: "My Product") { yielded = true }
      expect(yielded).to eq false
    end
  end
end
