require 'spec_helper'

describe Api::V1::ProductsController do

  before :each do
    @user = Factory(:master_user, product_view: true, api_auth_token: "Token", time_zone: "Hawaii", product_edit: true)
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
        expect(json['errors']).to eq ['Not Found']
      end

      it "returns a 404 if user can't access the product" do
        @user.update_attributes! product_view: false

        get "show", {id: @p.id, format: 'json', mf_uids: "prod_uid"}
        expect(response.status).to eq 404

        json = ActiveSupport::JSON.decode response.body
        expect(json['errors']).to eq ['Not Found']
      end
    end

    context "invalid token" do
      it "Raises an unauthorized error if there is no valid token" do
        # api access also sets required request header elements..so that's why it's called here
        allow_api_access @user

        @user.api_auth_token = "Invalid"
        @user.save!

        get "show", {id: 1}
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
      expect(json['errors']).to eq ['Not Found']
    end

    it "returns a 404 if user can't access the product" do
      @user.update_attributes! product_view: false

      get "by_uid", {uid: -1, format: 'json'}
      expect(response.status).to eq 404

      json = ActiveSupport::JSON.decode response.body
      expect(json['errors']).to eq ['Not Found']
    end
  end

  context "api_controller" do
    # These are tests that basically just isolate some functionality in the api_controller to test 
    # it.  I can't figure out how to do this straight up without being part of another controller test
    # class.  It has something to do w/ an rspec and/or authlogic expectation that there's only a single 
    # application controller in use for all of the app.
    before :each do
      # Set a baseline for the test of a valid state, then we can back out expected 
      allow_api_access @user
    end

    describe "validate_authtoken" do
      it "returns an unauthorized error when a request is missing an authorization header" do
        request.env["HTTP_AUTHORIZATION"] = nil
        get 'show', id: 1

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
          request.env['HTTP_ACCEPT'] = 'text/html'

          get 'show', id: 1

          expect(response.status).to eq 406
          json = ActiveSupport::JSON.decode response.body
          expect(json['errors']).to eq ["Request must include Accept header of 'application/json'."]
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
          get 'show', id: 1

          expect(response.status).to eq 200
          expect(Time.zone.name).to eq def_tz.name
          expect(User.current).to be_nil

          expect(request.env['exception_notifier.exception_data'][:user].id).to eq @user.id
        end
      end

      describe "error_handler" do
        it "handles a StatusableError and uses its data in the json response" do
          controller.should_receive(:show) do
            raise StatusableError.new "Error1", 501
          end

          get 'show', id: 1, format: 'json'
          expect(response.status).to eq 501
          json = ActiveSupport::JSON.decode response.body
          expect(json['errors']).to eq ["Error1"]
        end

        it "handles a StatusableError with multiple errors and uses its data in the json response" do
          controller.should_receive(:show) do
            raise StatusableError.new ["Error1", "Error2"], 501
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
          expect(json['errors']).to eq ["Not Found"]
        end

        it "handles all other exceptions as server errors" do
          Rails.stub(:env).and_return('not_test') #errors are raised in test
          controller.should_receive(:show) do
            raise "Oops, something weird happened!"
          end

          get 'show', id: 1, format: 'json'
          expect(response.status).to eq 500
          json = ActiveSupport::JSON.decode response.body
          expect(json['errors']).to eq ["Oops, something weird happened!"]
        end
      end
    end
  end

  describe "index" do
    before :each do
      allow_api_access @user
      @p1 = Factory(:product, unit_of_measure: "UOM")
      @p2 = Factory(:product, unit_of_measure: "UOM")

    end
    it "renders a search result" do
      get :index
      expect(response).to be_success
      j = JSON.parse response.body
      uids = j['results'].collect{|r| r['prod_uid']}
      expect(uids).to include @p1.unique_identifier
      expect(uids).to include @p2.unique_identifier
    end

    it "limits search result 'columns' to those requested" do
      get :index, {fields: 'prod_uid, prod_uom'}
      expect(response).to be_success
      j = JSON.parse response.body

      # 3 keys = id, uid, uom
      expect(j['results'].first.keys.size).to eq 3
      expect(j['results'].first['prod_uom']).to eq @p1.unit_of_measure
      expect(j['results'].second.keys.size).to eq 3
    end

    it "limits search results by params" do
      get :index, {fields: 'prod_uid', sid1: 'prod_uid', sop1: "eq", sv1: @p1.unique_identifier}

      expect(response).to be_success
      j = JSON.parse response.body
      expect(j['results'].size).to eq 1
      expect(j['results'].first['prod_uid']).to eq @p1.unique_identifier
    end
  end

  describe "create" do
    before :each do
      allow_api_access @user
      @country = Factory(:country)
    end

    it "creates a new product" do
      # Make sure we're testing that it creates the whole product heirarchy (don't need to go into
      # TOO much detail here since this uses code that's thoroughly tested elsewhere)
      params = {
        :prod_uid => 'unique_id',
        :classifications_attributes => [{
          :class_cntry_iso => @country.iso_code,
          :tariff_records_attributes => [{
            :hts_hts_1 => '1234.56.7890'
          }]
        }]
      }
      post :create, {product: params}
      expect(response).to be_success
      j = JSON.parse response.body

      p = Product.where(unique_identifier: 'unique_id').first

      expect(j['product']['id']).to eq p.id
    end

    it "raises an error if product validation fails" do
      p = Factory(:product)
      # Try and create a non-unique product - which should always trip a failure
      params = {:prod_uid => p.unique_identifier}

      post :create, {product: params}
      expect(response.status).to eq 400

      j = JSON.parse response.body
      expect(j['errors'].first).to eq "Unique identifier has already been taken"
    end

    it "raises an error if the user cannot access the product" do
      @user.update_attributes! product_edit: false

      params = {:prod_uid => 'uid'}

      post :create, {product: params}
      expect(response.status).to eq 403
      j = JSON.parse response.body
      expect(j['errors'].first).to eq "You do not have permission to save this Product."
    end
  end

  describe "update" do
    before :each do
      allow_api_access @user
    end

    it "updates an existing product" do
      country = Factory(:country)
      p = Factory(:product)

      params = {
        :id => p.id,
        :prod_uom => "UOM",
        :classifications_attributes => [{
          :class_cntry_iso => country.iso_code,
          :tariff_records_attributes => [{
            :hts_hts_1 => '1234.56.7890'
          }]
        }]
      }

      post :update, {id: p.id, product: params}

      expect(response).to be_success
      j = JSON.parse response.body

      expect(j['product']['classifications'].first['class_cntry_iso']).to eq country.iso_code
      expect(j['product']['classifications'].first['tariff_records'].first['hts_hts_1']).to eq "1234.56.7890"
      # Check to make sure that values that are autopopulated are sent too
      expect(j['product']['classifications'].first['tariff_records'].first['hts_line_number']).to eq 1
    end

    it "raises an error if product isn't found" do
      params = {
        :id => 12345,
        :prod_uom => "UOM",
      }

      post :update, {id: 12345, product: params}
      expect(response.status).to eq 404
      j = JSON.parse response.body
      expect(j['errors'].first).to eq "Product Not Found"
    end

    it "raises an error if user doesn't have ability to edit product" do
      @user.update_attributes! product_edit: false

      p = Factory(:product)
      params = {
        :id => p.id,
        :prod_uom => "UOM"
      }
      post :update, {id: p.id, product: params}
      expect(response).to be_forbidden
      j = JSON.parse response.body
      expect(j['errors'].first).to eq "You do not have permission to save this Product."
    end
  end
end