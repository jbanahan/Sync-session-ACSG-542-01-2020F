require 'spec_helper'

describe LinkableAttachment do
  context 'integrity checks' do
    it 'should require model_field_uid' do
      a = LinkableAttachment.create(:value=>'abc')
      a.errors.full_messages.should have(1).message
    end
    it 'should require value' do
      a = LinkableAttachment.create(:model_field_uid=>'prod_uid')
      a.errors.full_messages.should have(1).message
    end
    it 'should save with model_field_uid and value' do
      a = LinkableAttachment.create(:model_field_uid=>'prod_uid',:value=>'abc')
      a.errors.should be_empty
      a.id.should > 0
    end
  end
  context 'attachment' do
    it 'should allow an attachment to be created' do
      linkable = Factory(:linkable_attachment)
      att = linkable.create_attachment
      att.attachable.should == linkable
    end
  end
  context 'link trigger' do
    it 'should call submit attachment link processing to delayed_job on save' do
      LinkedAttachment.should_receive(:delay).and_return(LinkedAttachment)
      LinkableAttachment.create(:model_field_uid=>'ord_ord_date',:value=>'2011-01-01')
    end
    it 'should add linked model fields to memcached on save' do
      TestExtensions::MockCache.any_instance.should_receive(:set).with("LinkableAttachment:model_field_uids",['ord_ord_num'])
      LinkableAttachment.create(:model_field_uid=>'ord_ord_num',:value=>'v')
    end
  end
  describe 'model_field' do
    it 'should return a good model field' do
      linkable = Factory(:linkable_attachment,:model_field_uid=>'ord_ord_num')
      linkable.model_field.uid.should == :ord_ord_num
    end
    it 'should return nil for a bad model filed' do
      Factory(:linkable_attachment,:model_field_uid=>'somethingbad').model_field.should be_nil
    end
  end
  describe 'model_field_uids' do
    it 'should return distinct list of model_field_uids in table' do
      ['f1','f2','f3','f1','f2','f4'].each {|m| Factory(:linkable_attachment, :model_field_uid=>m)}

      uids = LinkableAttachment.model_field_uids
      uids.to_a.sort.should == ['f1','f2','f3','f4']
    end
    it 'should return an empty array if no records' do
      LinkableAttachment.model_field_uids.should_not be nil 
    end
    it 'should try to get model_fields from cache before hitting db' do
      TestExtensions::MockCache.any_instance.should_receive(:get).with("LinkableAttachment:model_field_uids").and_return(nil)
      LinkableAttachment.model_field_uids
    end
  end
end
