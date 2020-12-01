describe SalesOrder do

  describe 'linkable attachments' do
    it 'should have linkable attachments' do
      s = FactoryBot(:sales_order, :order_number=>'ordn')
      linkable = FactoryBot(:linkable_attachment, :model_field_uid=>'sale_order_number', :value=>'ordn')
      linked = LinkedAttachment.create(:linkable_attachment_id=>linkable.id, :attachable=>s)
      s.reload
      expect(s.linkable_attachments.first).to eq(linkable)
    end
  end

end
