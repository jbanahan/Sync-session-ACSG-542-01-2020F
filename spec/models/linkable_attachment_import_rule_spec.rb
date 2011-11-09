require 'spec_helper'

describe LinkableAttachmentImportRule do
  context 'validations' do
    it 'should validate unique paths' do
      should_work = Factory("linkable_attachment_import_rule",:path=>'f')
      should_not_work = LinkableAttachmentImportRule.create(:path=>'f',:model_field_uid=>'prod_uid')
      should_not_work.errors[:path].should have(1).error
    end
    it 'should require path' do
      should_not_work = LinkableAttachmentImportRule.create(:model_field_uid=>'prod_uid')
      should_not_work.errors[:path].should have(1).error
    end
    it 'should require model_field_uid' do
      should_not_work = LinkableAttachmentImportRule.create(:path=>'/something_good')
      should_not_work.errors[:model_field_uid].should have(1).error
    end
  end

  context 'import' do
    before(:each) do
      #make some that shouldn't match
      3.times {Factory(:linkable_attachment_import_rule)}
      @file = Tempfile.new(['linkable','csv'])
      @file.write 'abc'
      @file.flush
    end

    describe 'path matching' do
      it 'should return nil if no matches' do
        result = LinkableAttachmentImportRule.import @file, 'original_file_name.xls', '/path/not/found'
        result.should be nil
      end
    
      context 'good match' do
        before(:each) do
          @path = '/path/found'
          @original_file_name = 'ofn.csv'
          @rule = Factory(:linkable_attachment_import_rule, :path=>@path)
          @result = LinkableAttachmentImportRule.import @file, @original_file_name, @path
        end
        it 'should create linkable attachment' do
          @result.should be_a LinkableAttachment
          @result.id.should > 0
        end
        it 'should attach file' do
          @result.attachment.id.should > 0
          @result.attachment.attached_file_name.should == @original_file_name
        end
        it 'should set model field uid' do
          @result.model_field_uid.should == @rule.model_field_uid
        end
      end
    end
    
    describe 'set linkable attachment value by original file name first segment' do
      before(:each) do 
        @path = '/some/path'
        @rule = Factory(:linkable_attachment_import_rule, :path=>@path)
      end
      it 'should set by space as first choice' do
        result = LinkableAttachmentImportRule.import @file, 'a.b_some file.csv', @path 
        result.value.should == 'a.b_some'
      end
      it 'should set by underscore as second choice' do
        result = LinkableAttachmentImportRule.import @file, 'a.b_some.csv', @path
        result.value.should == 'a.b'
      end
      it 'should set by period as third choice' do
        result = LinkableAttachmentImportRule.import @file, 'a.csv', @path
        result.value.should == 'a'
      end
      it 'should set full name as last choice' do
        result = LinkableAttachmentImportRule.import @file, 'abcdef', @path
        result.value.should == 'abcdef'
      end
    end
  end
end
