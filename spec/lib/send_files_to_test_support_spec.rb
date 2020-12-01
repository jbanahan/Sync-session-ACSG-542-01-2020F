# belongs under `describe OpenChain::SendFilesToTestSupport` but RSpec doesn't allow it
class FakeController < ApplicationController; end
describe FakeController, type: :controller do # rubocop:disable RSpec/MultipleDescribes
  controller do
    include OpenChain::SendFilesToTestSupport

    def send_to_test
      entries = params[:id] ? Entry.find(params[:id]) : Entry.all
      send_to_test_redirect(entries) { |sendable| sendable.test_meth  } # rubocop:disable Style/SymbolProc
    end
  end

  let!(:ent1) { FactoryBot(:entry, last_file_bucket: 'the_bucket', last_file_path: 'the_path') }
  let!(:ent2) { FactoryBot(:entry, last_file_bucket: 'the_bucket', last_file_path: 'bad_file') }
  let(:user) { FactoryBot(:user) }

  before do
    allow_any_instance_of(Entry).to receive(:can_view?).and_return true
    routes.draw { post "send_to_test" => "fake#send_to_test"}
    sign_in_as user
  end

  around do |example|
    Entry.class_eval { def test_meth; end; }
    example.run
    Entry.class_eval { remove_method :test_meth }
  end

  describe "send_to_test_redirect" do
    it "yields single object, renders message, redirects" do
      expect_any_instance_of(Entry).to receive(:test_meth) { |ent| expect(ent.id).to eq ent.id }
      post :send_to_test, id: ent1.id
      expect(flash[:notices]).to eq ["File has been queued to be sent to test."]
      expect(flash[:errors]).to be_nil
      expect(response).to be_redirect
    end

    it "yields multiple objects, renders messages, redirects" do
      expect_any_instance_of(Entry).to receive(:test_meth) { |ent| expect(ent.id).to eq ent.id }
      post :send_to_test, ids: [ent1.id, ent2.id]
      expect(flash[:notices]).to be_nil
      expect(flash[:errors]).to eq ["One or more files cannot be sent to test.",
                                    "The following Entry could not be found and may have been purged: ID #{ent2.id}",
                                    "The remaining files have been sent."]
      expect(response).to be_redirect
    end
  end
end

describe OpenChain::SendFilesToTestSupport do
  describe described_class::MessageHandler do
    let!(:user) { FactoryBot(:sys_admin_user) }

    context "object with integration file" do
      subject { described_class.new true }

      let!(:prod) { FactoryBot(:product, last_file_bucket: 'the_bucket', last_file_path: 'the_path') }

      before { allow(prod).to receive(:can_view?).and_return true }

      it "returns notification if no errors" do
        expect(subject.can_send?(prod, user)).to eq true
        expect(subject.entity_count).to eq 1
        expect(subject.messages).to eq ["Integration file has been queued to be sent to test."]
      end

      it "returns error message if file can't be found" do
        prod.update! last_file_path: 'bad_file'

        expect(subject.can_send?(prod, user)).to eq false
        expect(subject.entity_count).to eq 1
        expect(subject.messages).to eq ["One or more integration files cannot be sent to test.",
                                        "The following Product could not be found and may have been purged: ID #{prod.id}"]
      end

      it "returns error message if object doesn't support this behavior" do
        company = FactoryBot(:company)

        allow(company).to receive(:can_view?).and_return true

        expect(subject.can_send?(company, user)).to eq false
        expect(subject.entity_count).to eq 1
        expect(subject.messages).to eq ["One or more integration files cannot be sent to test.",
                                        "Company is an invalid type: ID #{company.id}"]
      end

      it "returns error message if user doesn't have permission to view product" do
        allow(prod).to receive(:can_view?).and_return false

        expect(subject.can_send?(prod, user)).to eq false
        expect(subject.entity_count).to eq 1
        expect(subject.messages).to eq ["One or more integration files cannot be sent to test.",
                                        "You do not have permission to send the following Product to test: ID #{prod.id}"]
      end

      it "returns multiple error messages" do
        missing_prod_1 = FactoryBot(:product, last_file_bucket: 'the_bucket', last_file_path: 'bad_file')
        missing_prod_2 = FactoryBot(:product, last_file_bucket: 'the_bucket', last_file_path: 'bad_file')
        allow(missing_prod_1).to receive(:can_view?).and_return true
        allow(missing_prod_2).to receive(:can_view?).and_return true

        missing_path_prod_1 = FactoryBot(:product, last_file_bucket: 'the_bucket', last_file_path: nil)
        missing_path_prod_2 = FactoryBot(:product, last_file_bucket: 'the_bucket', last_file_path: nil)
        allow(missing_path_prod_1).to receive(:can_view?).and_return true
        allow(missing_path_prod_2).to receive(:can_view?).and_return true

        wrong_type_1 = FactoryBot(:company)
        wrong_type_2 = FactoryBot(:company)
        allow(wrong_type_1).to receive(:can_view?).and_return true
        allow(wrong_type_2).to receive(:can_view?).and_return true

        no_permission_1 = FactoryBot(:product, last_file_bucket: 'the_bucket', last_file_path: 'the_path')
        no_permission_2 = FactoryBot(:product, last_file_bucket: 'the_bucket', last_file_path: 'the_path')
        allow(no_permission_1).to receive(:can_view?).and_return false
        allow(no_permission_2).to receive(:can_view?).and_return false

        expect(subject.can_send?(prod, user)).to eq true
        expect(subject.can_send?(missing_prod_1, user)).to eq false
        expect(subject.can_send?(missing_prod_2, user)).to eq false
        expect(subject.can_send?(missing_path_prod_1, user)).to eq false
        expect(subject.can_send?(missing_path_prod_2, user)).to eq false
        expect(subject.can_send?(wrong_type_1, user)).to eq false
        expect(subject.can_send?(wrong_type_2, user)).to eq false
        expect(subject.can_send?(no_permission_1, user)).to eq false
        expect(subject.can_send?(no_permission_2, user)).to eq false
        expect(subject.entity_count).to eq 9
        expect(subject.messages).to eq ["One or more integration files cannot be sent to test.",
                                        "The following Products could not be found and may have been purged: ID #{missing_prod_1.id}, #{missing_prod_2.id}",
                                        "Company is an invalid type: ID #{wrong_type_1.id}, #{wrong_type_2.id}",
                                        "You do not have permission to send the following Products to test: ID #{no_permission_1.id}, #{no_permission_2.id}",
                                        "The remaining integration files have been sent."]
      end
    end

    context "object with standard file" do
      let(:inbound) { FactoryBot(:inbound_file, s3_bucket: "bucket", s3_path: "path") }

      before { allow(inbound).to receive(:can_view?).and_return true }

      it "returns notification if no errors" do
        expect(subject.can_send?(inbound, user)).to eq true
        expect(subject.entity_count).to eq 1
        expect(subject.messages).to eq ["File has been queued to be sent to test."]
      end

      it "returns error message if file can't be found" do
        inbound.update! s3_path: 'bad_file'

        expect(subject.can_send?(inbound, user)).to eq false
        expect(subject.entity_count).to eq 1
        expect(subject.messages).to eq ["One or more files cannot be sent to test.",
                                        "The following Inbound File could not be found and may have been purged: ID #{inbound.id}"]
      end

      it "returns error message if file path is missing" do
        inbound.update! s3_path: nil

        expect(subject.can_send?(inbound, user)).to eq false
        expect(subject.entity_count).to eq 1
        expect(subject.messages).to eq ["One or more files cannot be sent to test.",
                                        "The following Inbound File is missing a file path: ID #{inbound.id}"]
      end

      it "returns error message if file bucket is missing" do
        inbound.update! s3_bucket: nil

        expect(subject.can_send?(inbound, user)).to eq false
        expect(subject.entity_count).to eq 1
        expect(subject.messages).to eq ["One or more files cannot be sent to test.",
                                        "The following Inbound File is missing a file bucket: ID #{inbound.id}"]
      end
    end

  end

end
