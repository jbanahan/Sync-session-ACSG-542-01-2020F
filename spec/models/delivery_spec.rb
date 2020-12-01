describe Delivery do
  describe 'linkable attachments' do
    it 'should have linkable attachments' do
      s = FactoryBot(:delivery, :reference=>'ordn')
      linkable = FactoryBot(:linkable_attachment, :model_field_uid=>'del_reference', :value=>'ordn')
      linked = LinkedAttachment.create(:linkable_attachment_id=>linkable.id, :attachable=>s)
      s.reload
      expect(s.linkable_attachments.first).to eq(linkable)
    end
  end
end
