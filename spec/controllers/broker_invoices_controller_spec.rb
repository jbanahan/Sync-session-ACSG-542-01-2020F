describe BrokerInvoicesController do

  let! (:master_setup) do
    ms = stub_master_setup
    allow(ms).to receive(:entry_enabled?).and_return true
    allow(ms).to receive(:broker_invoice_enabled?).and_return true
    ms
  end

  before do
    sign_in_as(create(:user, company: create(:company, master: true), broker_invoice_edit: true, entry_view: true))
  end

  describe "sync_records" do
    let (:entry) { create(:entry) }
    let (:broker_invoice) { create(:broker_invoice, entry: entry) }

    it "shows sync_records" do
      get :sync_records, {id: broker_invoice.id}

      expect(assigns(:base_object)).to eq broker_invoice
      expect(assigns(:back_url)).to end_with "/broker_invoices/#{broker_invoice.id}"
      expect(assigns(:back_url)).not_to include "entries"
    end

    it "sets the back url to entry if entry_id is present" do
      get :sync_records, {id: broker_invoice.id, entry_id: entry.id}

      expect(assigns(:base_object)).to eq broker_invoice
      expect(assigns(:back_url)).to end_with "/entries/#{entry.id}"
    end
  end
end
