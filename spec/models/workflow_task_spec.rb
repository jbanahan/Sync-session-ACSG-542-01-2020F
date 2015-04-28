require 'spec_helper'

describe WorkflowTask do
  module OpenChain; module Test; class MyTestWorkflowTask
    def self.pass? wt
      wt.payload['pass']
    end
  end; end; end

  describe :for_user do
    it "should find workflow tasks for groups user is a member of" do
      # just setting up a standard instance to save on the DB writes of creating
      # a new instance for each task below
      wi = Factory(:workflow_instance)

      u = Factory(:user)
      g1 = Factory(:group)
      g1.users << u
      wt1A = Factory(:workflow_task,group:g1,workflow_instance:wi)
      wt1B = Factory(:workflow_task,group:g1,workflow_instance:wi)

      g2 = Factory(:group)
      g2.users << u
      wt2 = Factory(:workflow_task,group:g2,workflow_instance:wi)
      
      g_not_found = Factory(:group)
      wt3 = Factory(:workflow_task,group:g_not_found,workflow_instance:wi)

      expect(WorkflowTask.for_user(u).to_a).to eq [wt1A,wt1B,wt2]
    end
  end

  describe :not_passed do
    it "should find workflow tasks where passed_at is nil" do
      w1 = Factory(:workflow_task)
      w2 = Factory(:workflow_task,passed_at:1.minute.ago)
      expect(WorkflowTask.not_passed.to_a).to eq [w1]
    end
  end

  describe :for_base_object do
    it "should find workflow_task by base_object" do
      wt1 = Factory(:workflow_task)
      wt2 = Factory(:workflow_task)
      expect(WorkflowTask.for_base_object(wt1.workflow_instance.base_object).to_a).to eq [wt1]
    end
  end

  describe :object_to_test do
    it "should test target_object" do
      p = Product.new
      w = WorkflowTask.new
      w.target_object = p
      expect(w.object_to_test).to be p
    end
    it "should test base_object if target_object.nil?" do
      p = Product.new
      w = WorkflowTask.new
      w.should_receive(:base_object).and_return(p)
      expect(w.object_to_test).to be p
    end
  end

  describe :are_overdue do
    it "should find workflow_tasks with due_at in the past" do
      wt1 = Factory(:workflow_task,due_at:1.year.ago)
      wt2 = Factory(:workflow_task,due_at:1.year.from_now)
      wt3 = Factory(:workflow_task,due_at:nil)
      expect(WorkflowTask.are_overdue.to_a).to eq [wt1]
    end
  end

  describe :overdue? do
    it "should be true when workflow_task due_at is in the past" do
      expect(WorkflowTask.new(due_at:1.hour.ago)).to be_overdue
    end
    it "should be false when workflow_task due_at is in the future" do
      expect(WorkflowTask.new(due_at:1.hour.from_now)).to_not be_overdue
    end
    it "should be false when workflow_task doesn't have a due_at value" do
      expect(WorkflowTask.new).to_not be_overdue
    end
  end
  describe :test_class do
    it "should get test class" do
      wt = WorkflowTask.new(test_class_name:"OpenChain::Test::MyTestWorkflowTask")
      expect(wt.test_class).to eq OpenChain::Test::MyTestWorkflowTask
    end
  end
  describe :test! do
    it "should use test class and set passed" do
      wt = Factory(:workflow_task,test_class_name:"OpenChain::Test::MyTestWorkflowTask",payload_json:'{"pass":"yes"}')
      expect(wt.passed_at).to be_nil
      expect(wt.test!).to be_true
      expect(wt.passed_at).to_not be_nil

    end
    it "should use test class and clear passed" do
      wt = Factory(:workflow_task,test_class_name:"OpenChain::Test::MyTestWorkflowTask",payload_json:'{"a":"b"}',passed_at:Time.now)
      expect(wt.passed_at).to_not be_nil
      expect(wt.test!).to be_false
      expect(wt.passed_at).to be_nil
    end
  end

  describe :can_edit? do
    it "can edit if user in group and can view object" do
      u = Factory(:user)
      g = Factory(:group)
      g.users << u
      o = Factory(:order)
      Order.any_instance.stub(:can_view?).and_return true
      wi = Factory(:workflow_instance,base_object:o)
      wt = Factory(:workflow_task,workflow_instance:wi,group:g)
      expect(wt.can_edit?(u)).to be_true
    end
    it "cannot edit if user not in group" do
      u = Factory(:user)
      g = Factory(:group)
      # NOT ADDING USER TO GROUP HERE :)
      o = Factory(:order)
      Order.any_instance.stub(:can_view?).and_return true
      wi = Factory(:workflow_instance,base_object:o)
      wt = Factory(:workflow_task,workflow_instance:wi,group:g)
      expect(wt.can_edit?(u)).to be_false
    end
    it "cannot edit if user cannot view object" do
      u = Factory(:user)
      g = Factory(:group)
      g.users << u
      o = Factory(:order)
      Order.any_instance.stub(:can_view?).and_return false # <<<< this makes the test go to false
      wi = Factory(:workflow_instance,base_object:o)
      wt = Factory(:workflow_task,workflow_instance:wi,group:g)
      expect(wt.can_edit?(u)).to be_false

    end
  end
end
