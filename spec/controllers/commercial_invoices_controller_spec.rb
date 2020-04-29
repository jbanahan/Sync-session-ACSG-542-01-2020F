describe CommercialInvoicesController do
  describe "show" do
    before :each do
      u = Factory(:user, :company=>Factory(:company, :master=>true))

      sign_in_as u
      @ci = Factory(:commercial_invoice)
    end
    it "should show if user can view" do
      allow_any_instance_of(CommercialInvoice).to receive(:can_view?).and_return(true)
      get :show, :id=>@ci.id
      expect(response).to be_success
      expect(assigns(:ci)).to eq(@ci)
    end
    it "should not show if user cannot view" do
      allow_any_instance_of(CommercialInvoice).to receive(:can_view?).and_return(false)
      get :show, :id=>@ci.id
      expect(response).to redirect_to request.referrer
    end
    it "should assign shipment if linked" do
      shipment_line = Factory(:shipment_line, :quantity=>10)
      order_line = Factory(:order_line, :product=>shipment_line.product, :price_per_unit=>10.0, :quantity=>100, :order=>Factory(:order, :vendor=>shipment_line.shipment.vendor))
      inv_line = Factory(:commercial_invoice_line, :quantity=>10, :commercial_invoice=>@ci)
      PieceSet.create!(:shipment_line_id=>shipment_line.id, :order_line_id=>order_line.id, :commercial_invoice_line_id=>inv_line.id, :quantity=>10)

      allow_any_instance_of(CommercialInvoice).to receive(:can_view?).and_return(true)
      get :show, :id=>@ci.id
      expect(response).to be_success
      expect(assigns(:ci)).to eq(@ci)
      expect(assigns(:shipment)).to eq(shipment_line.shipment)
    end
  end
end
