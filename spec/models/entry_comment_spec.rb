require 'spec_helper'

describe EntryComment do
  before :each do 
    @entry = Factory(:entry)
  end

  it 'should set public_comment field in before_save callback' do
    @entry.entry_comments.build(:body => 'This is a public comment.')
    @entry.save!

    @entry.entry_comments.first.public_comment.should be_true
  end

  context :private_comment_strings do
    it "should identify comments as private" do
      @entry.entry_comments.build(:body => 'DOCUMENT IMAGE CREATED FOR')
      @entry.save!

      @entry.entry_comments.first.public_comment.should be_false
    end
    it "should identify 'Customer has been changed from' as private" do
      @entry.entry_comments.build(:body => 'CUSTOMER HAS BEEN CHANGED FROM')
      @entry.save!

      @entry.entry_comments.first.public_comment.should be_false
    end
    it "should identify 'E/S Query received - Entry Summary Date updated' as private" do
      @entry.entry_comments.build(:body => 'E/S QUERY RECEIVED - ENTRY SUMMARY DATE UPDATED')
      @entry.save!

      @entry.entry_comments.first.public_comment.should be_false
    end
    it "should identify 'Entry Summary Date Query Sent' as private" do
      @entry.entry_comments.build(:body => 'ENTRY SUMMARY DATE QUERY SENT')
      @entry.save!

      @entry.entry_comments.first.public_comment.should be_false
    end
    it "should identify 'Pay Due not changed, Same Pay Due Date' as private" do
      @entry.entry_comments.build(:body => 'PAY DUE NOT CHANGED, SAME PAY DUE DATE')
      @entry.save!

      @entry.entry_comments.first.public_comment.should be_false
    end
    it "should identify 'Payment Type Changed' as private" do
      @entry.entry_comments.build(:body => 'PAYMENT TYPE CHANGED')
      @entry.save!

      @entry.entry_comments.first.public_comment.should be_false
    end
    it "should identify 'STMNT DATA REPLACED AS REQUESTED' as private" do
      @entry.entry_comments.build(:body => 'stmnt data replaced as requested')
      @entry.save!

      @entry.entry_comments.first.public_comment.should be_false
    end
    it "should identify 'stmt...authorized' as private" do
      @entry.entry_comments.build(:body => 'STMTabunchofothertextAUTHORIZED')
      @entry.save!

      @entry.entry_comments.first.public_comment.should be_false
    end
  end

  context :can_view? do
    before :each do
      @user = Factory(:master_user, :entry_view => true)
      MasterSetup.get.update_attributes :entry_enabled => true
    end

    it "should allow anyone to view public comments" do
      @entry.entry_comments.build(:body => 'Random Comment')
      @entry.save!
      
      @entry.entry_comments.first.can_view?(@user).should be_true
    end

    it "should not allow users who can't view entry to view comment" do
      @user.entry_view = false

      @entry.entry_comments.build(:body => 'Random Comment')
      @entry.save!
      
      @entry.entry_comments.first.can_view?(@user).should be_false
    end

    it "should allow brokers to view private comments" do
      @user.company.broker = true
      @entry.entry_comments.build(:body => 'DOCUMENT IMAGE CREATED FOR')
      @entry.save!
      
      @entry.entry_comments.first.can_view?(@user).should be_true
    end

    it "should not allow non-brokers to view private comments" do
      @entry.entry_comments.build(:body => 'DOCUMENT IMAGE CREATED FOR')
      @entry.save!
      
      @entry.entry_comments.first.can_view?(@user).should be_false
    end
  end
end