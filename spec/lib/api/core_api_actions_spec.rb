describe OpenChain::Api::CoreApiActions do

  subject {
    Class.new do
      include OpenChain::Api::CoreApiActions

      def core_module
        CoreModule::BROKER_INVOICE
      end

      def get a, b
        raise "Mock me"
      end

      def put a, b
        raise "Mock me"
      end

      def post a, b
        raise "Mock me"
      end
    end.new
  }

  describe "entity_name" do
    it "underscorizes the core module class name" do
      expect(subject.entity_name).to eq "broker_invoice"
    end
  end

  describe "module_path" do
    it "pluralizes and underscorizes the core module class name" do
      expect(subject.module_path).to eq "broker_invoices"
    end
  end

  describe "show" do
    it "utilizizes the get method to return data" do
      expect(subject).to receive(:get).with("/broker_invoices/1", {})
      subject.show 1, []
    end

    it "marshals the model field names into the request" do
      expect(subject).to receive(:get).with("/broker_invoices/1", {"fields" => "bi_entry_number,bi_invoice_number"})
      subject.show 1, [:bi_entry_number, :bi_invoice_number]
    end
  end

  describe "create" do
    it "posts given object hash to module path" do
      hash = {"field" => "value"}
      expect(subject).to receive(:post).with("/broker_invoices", hash)

      subject.create(hash)
    end
  end

  describe "update" do
    it "puts given object has to module path" do
      hash = {"broker_invoice" => {"id" => 10, "field" => "value"}}
      expect(subject).to receive(:put).with("/broker_invoices/10", hash)

      subject.update(hash)
    end

    it "errors if no id attribute is set" do
      expect {subject.update({"id" => 10, "field" => "value"})}.to raise_error "All API update calls require an 'id' in the attribute hash."
    end
  end

  describe "search" do
    let (:criterion_1) {
      SearchCriterion.new model_field_uid: "bi_entry_number", operator: "eq", value: "123"
    }
    let (:criterion_2) {
     SearchCriterion.new model_field_uid: "bi_invoice_number", operator: "eq", value: "456"
    }

    let (:sort_1) {
      SortCriterion.new model_field_uid: "bi_invoice_number"
    }
    let (:sort_2) {
     SortCriterion.new model_field_uid: "bi_entry_number", descending: true
    }

    it "assembles search" do
      request = {
        "fields" => "bi_entry_number,bi_invoice_number",
        "page"=>"1",
        "per_page"=>"50",
        "sid0"=>"bi_entry_number", "sop0"=>"eq", "sv0"=>"123",
        "sid1"=>"bi_invoice_number", "sop1"=>"eq", "sv1"=>"456",
        "oid0"=>"bi_invoice_number",
        "oid1"=>"bi_entry_number", "oo1"=>"D"
      }

      expect(subject).to receive(:get).with("/broker_invoices", request)

      subject.search(fields: ["bi_entry_number", "bi_invoice_number"], search_criterions: [criterion_1, criterion_2], sorts: [sort_1, sort_2], page: 1)
    end

    it "allows changing the per page total" do
      expect(subject).to receive(:get).with("/broker_invoices", hash_including("per_page" => "1"))
      subject.search(fields: [], search_criterions: [], sorts: [], page: 1, per_page: 1)
    end
  end

  describe "get_wrapper" do
    it "transparently handles not found errors" do
      val = subject.get_request_wrapper {
        e = OpenChain::Api::ApiClient::ApiError.new 404, {}
        raise e
      }
      expect(val).to eq({"broker_invoice" => nil})
    end

    it "raises other errors" do
      expect {
        subject.get_request_wrapper { raise "error"}
      }.to raise_error "error"
    end
  end

  describe "mf_uid_list_to_param" do
    it "converts an array of model field uid symbols to a request parameter hash" do
      param = subject.mf_uid_list_to_param [:a, :b, :c, :d]
      expect(param['fields']).to eq "a,b,c,d"
    end

    it "handles nil uid lists" do
      expect(subject.mf_uid_list_to_param(nil)).to eq({})
    end
  end
end