class WorkflowInstance < ActiveRecord::Base
  belongs_to :base_object, polymorphic: true, inverse_of: :workflow_instances

  has_many :workflow_tasks, dependent: :destroy, inverse_of: :workflow_instance
  
  validates :base_object, presence: true
  validates :workflow_decider_class, presence: true


end
