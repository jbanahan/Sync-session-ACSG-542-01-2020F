require 'spec_helper'

describe Api::V1::ProductsController do

  before :each do
    @user = Factory(:master_user, product_view: true, api_auth_token: "Token", time_zone: "Hawaii")
  end

  describe "#show" do
    context "with valid token" do
      before :each do
        allow_api_access @user
        @p = Factory(:product)
      end

      it "finds the product and returns it with the specified model fields" do
        get "show", {id: @p.id, format: 'json', mf_uids: "prod_uid"}
        expect(response).to be_success
        json = ActiveSupport::JSON.decode response.body
        expect(json['product']).to eq({
          'id' => @p.id,
          'prod_uid' => @p.unique_identifier
        })
      end

      it "returns a 404 if the product isn't found" do
        get "show", {id: -1, format: 'json'}
        expect(response.status).to eq 404

        json = ActiveSupport::JSON.decode response.body
        expect(json['errors']).to eq ['Not Found.']
      end

      it "returns a 404 if user can't access the product" do
        @user.update_attributes! product_view: false

        get "show", {id: @p.id, format: 'json', mf_uids: "prod_uid"}
        expect(response.status).to eq 404

        json = ActiveSupport::JSON.decode response.body
        expect(json['errors']).to eq ['Not Found.']
      end
    end

    context "invalid token" do
      it "Raises an unauthorized error if there is no valid token" do
        @user.api_auth_token = "Invalid"
        @user.save!

        get "show", {id: 1, format: 'json'}
        expect(response.status).to eq 401

        json = ActiveSupport::JSON.decode response.body
        expect(json['errors']).to eq ['Access denied.']
      end
    end
  end


  describe "by_uid" do
    before :each do
      @p = Factory(:product)
      allow_api_access @user
    end

    it "find a product by unique identifier" do
      get "by_uid", {uid: @p.unique_identifier, format: 'json', mf_uids: "prod_uid"}
      expect(response).to be_success
      json = ActiveSupport::JSON.decode response.body
      expect(json['product']).to eq({
        'id' => @p.id,
        'prod_uid' => @p.unique_identifier
      })
    end

    it "returns a 404 if the product isn't found" do
      get "by_uid", {uid: -1, format: 'json'}
      expect(response.status).to eq 404

      json = ActiveSupport::JSON.decode response.body
      expect(json['errors']).to eq ['Not Found.']
    end

    it "returns a 404 if user can't access the product" do
      @user.update_attributes! product_view: false

      get "by_uid", {uid: -1, format: 'json'}
      expect(response.status).to eq 404

      json = ActiveSupport::JSON.decode response.body
      expect(json['errors']).to eq ['Not Found.']
    end
  end

  describe "model_fields" do
    before :each do
      allow_api_access @user
    end

    it "returns all model fields for Product" do
      get 'model_fields', {format: 'json'}

      expect(response).to be_success
      json = ActiveSupport::JSON.decode response.body

      # Just validate that we have the correct # of fields
      expect(json['product']).to have(CoreModule::PRODUCT.model_fields(@user).length).items
      expect(json['classifications']).to have(CoreModule::CLASSIFICATION.model_fields(@user).length).items
      expect(json['tariff_records']).to have(CoreModule::TARIFF.model_fields(@user).length).items
    end

    it "returns a 404 if the user can't access products" do
      @user.update_attributes! product_view: false
      get 'model_fields', {format: 'json'}
      expect(response.status).to eq 404

      json = ActiveSupport::JSON.decode response.body
      expect(json['errors']).to eq ['Not Found.']
    end
  end

  context "api_controller" do
    # These are tests that basically just isolate some functionality in the api_controller to test 
    # it.  I can't figure out how to do this straight up without being part of another controller test
    # class.  It has something to do w/ an rspec and/or authlogic expectation that there's only a single 
    # application controller in use for all of the app.

    describe "validate_authtoken" do
      it "returns an unauthorized error when a request is missing an authorization header" do
        get 'show', id: 1, format: 'json'

        expect(response.status).to eq 401
        json = ActiveSupport::JSON.decode response.body
        expect(json['errors']).to eq ['Access denied.']
      end

      it "returns an unauthorized error when a request has an invalid authorization header" do
        request.env['HTTP_AUTHORIZATION'] = "Invalid"

        get 'show', id: 1, format: 'json'

        expect(response.status).to eq 401
        json = ActiveSupport::JSON.decode response.body
        expect(json['errors']).to eq ['Access denied.']
      end

      it "returns an unauthorized error when a request has a malformed authorization header" do
        # This header crashed the rails token parser
        request.env['HTTP_AUTHORIZATION'] = "Token invalid"

        get 'show', id: 1, format: 'json'

        expect(response.status).to eq 401
        json = ActiveSupport::JSON.decode response.body
        expect(json['errors']).to eq ['Access denied.']
      end

      it "returns unauthorized if the user in the token is not present" do
        request.env['HTTP_AUTHORIZATION'] = ActionController::HttpAuthentication::Token.encode_credentials "nouserbythisnamehere:#{@user.api_auth_token}"

        get 'show', id: 1, format: 'json'

        expect(response.status).to eq 401
        json = ActiveSupport::JSON.decode response.body
        expect(json['errors']).to eq ['Access denied.']
      end

      it "returns unauthorized if the auth token does not match the user's authtoken" do
        request.env['HTTP_AUTHORIZATION'] = ActionController::HttpAuthentication::Token.encode_credentials "#{@user.username}:#{@user.api_auth_token + "b"}"

        get 'show', id: 1, format: 'json'

        expect(response.status).to eq 401
        json = ActiveSupport::JSON.decode response.body
        expect(json['errors']).to eq ['Access denied.']
      end

      it "executes the action with valid authorization header" do
        request.env['HTTP_AUTHORIZATION'] = ActionController::HttpAuthentication::Token.encode_credentials "#{@user.username}:#{@user.api_auth_token}"
        controller.should_receive(:show) do
          controller.render json: {'ok'=>true}
        end
        get 'show', id: 1, format: 'json'
        expect(response.status).to eq 200
        json = ActiveSupport::JSON.decode response.body
        expect(json['ok']).to be_true
      end
    end

    context "has valid api token" do
      before :each do 
        allow_api_access @user
      end

      describe "validate_format" do
        # There's really no need for an opposite test here because pretty much every other test
        # proves it works.
        it "raises an error for non-json requests" do
          get 'show', id: 1, format: "html"

          expect(response.status).to eq 406
          json = ActiveSupport::JSON.decode response.body
          expect(json['errors']).to eq ["Format html not supported."]
        end
      end

      describe "set_user_settings" do
        it "should set global user settings" do
          def_tz = Time.zone
          controller.should_receive(:show) do
            expect(User.current.id).to eq @user.id
            expect(Time.zone.name).to eq @user.time_zone

            controller.render json: {'ok'=>true}
          end
          get 'show', id: 1, format: 'json'

          expect(response.status).to eq 200
          expect(Time.zone.name).to eq def_tz.name
          expect(User.current).to be_nil

          expect(request.env['exception_notifier.exception_data'][:user].id).to eq @user.id
        end
      end

      describe "error_handler" do
        it "handles a StatusableError and uses its data in the json response" do
          controller.should_receive(:show) do
            raise Api::V1::ApiController::StatusableError.new "Error1", 501
          end

          get 'show', id: 1, format: 'json'
          expect(response.status).to eq 501
          json = ActiveSupport::JSON.decode response.body
          expect(json['errors']).to eq ["Error1"]
        end

        it "handles a StatusableError with multiple errors and uses its data in the json response" do
          controller.should_receive(:show) do
            raise Api::V1::ApiController::StatusableError.new ["Error1", "Error2"], 501
          end

          get 'show', id: 1, format: 'json'
          expect(response.status).to eq 501
          json = ActiveSupport::JSON.decode response.body
          expect(json['errors']).to eq ["Error1", "Error2"]
        end

        it "handles Record Not Found errors and returns 404" do
          controller.should_receive(:show) do
            raise ActiveRecord::RecordNotFound
          end

          get 'show', id: 1, format: 'json'
          expect(response.status).to eq 404
          json = ActiveSupport::JSON.decode response.body
          expect(json['errors']).to eq ["Not Found."]
        end

        it "handles all other exceptions as server errors" do
          controller.should_receive(:show) do
            raise "Oops, something weird happened!"
          end

          get 'show', id: 1, format: 'json'
          expect(response.status).to eq 500
          json = ActiveSupport::JSON.decode response.body
          expect(json['errors']).to eq ["Oops, something weird happened!"]
        end
      end

      describe "render_obj" do
        before :each do 
          @product = Factory(:product)
          @params = {id: @product.id, mf_uids: [:prod_uid], format: "json"}
        end

        it "renders an object using the api jsonizer" do
          controller.should_receive(:show) do
            controller.render_obj @product
          end

          controller.jsonizer.should_receive(:entity_to_json).with(instance_of(User), instance_of(Product), [:prod_uid]).and_return({"ok"=>true})

          get 'show', @params
          expect(response.status).to eq 200
        end

        it 'does not render objects the user cannot view' do
          Product.any_instance.should_receive(:can_view?).with(instance_of(User)).and_return false
          controller.should_receive(:show) do
            controller.render_obj @product
          end

          get 'show', @params
          expect(response.status).to eq 404
        end

        it 'renders a 404 if the object is nil' do
          controller.should_receive(:show) do
            controller.render_obj nil
          end

          get 'show', @params
          expect(response.status).to eq 404
        end
      end

      describe "show_module" do
        before :each do 
          @product = Factory(:product)
          @params = {id: @product.id, mf_uids: "prod_uid,prod_name", format: "json"}
        end

        it "renders an object using the api jsonizer" do
          controller.should_receive(:show) do
            controller.show_module Product
          end

          controller.jsonizer.should_receive(:entity_to_json).with(instance_of(User), instance_of(Product), ['prod_uid', 'prod_name']).and_return({"ok"=>true})

          get 'show', @params
          expect(response.status).to eq 200
        end

        it 'does not render objects the user cannot view' do
          Product.any_instance.should_receive(:can_view?).with(instance_of(User)).and_return false
          controller.should_receive(:show) do
            controller.show_module Product
          end

          get 'show', @params
          expect(response.status).to eq 404
        end

        it 'renders a 404 if the object is nil' do
          controller.should_receive(:show) do
            controller.show_module Product
          end

          @params[:id] = -1
          get 'show', @params
          expect(response.status).to eq 404
        end
      end

      describe 'render_model_field_list' do
        it "uses the jsonizer to render the full list of model fields for a module" do
          controller.should_receive(:show) do
            controller.render_model_field_list CoreModule::PRODUCT
          end
          controller.jsonizer.should_receive(:model_field_list_to_json).with(instance_of(User), CoreModule::PRODUCT).and_return({"ok"=>true})

          get 'show', {id: 1, format: "json"}
          expect(response.status).to eq 200
        end

        it "validates user has access to the core module" do
          controller.should_receive(:show) do
            controller.render_model_field_list CoreModule::PRODUCT
          end

          CoreModule::PRODUCT.should_receive(:view?).with(instance_of(User)).and_return false
          get 'show', {id: 1, format: "json"}
          expect(response.status).to eq 404
        end
      end
    end
  end
end