class EntitySnapshot < ActiveRecord::Base
  belongs_to :recordable, :polymorphic=>true
  belongs_to :user

  validates :recordable, :presence => true

  def self.create_from_entity entity
    cm = CoreModule.find_by_class_name entity.class.to_s
    raise "CoreModule could not be found for class #{entity.class.to_s}." if cm.nil?
    EntitySnapshot.create(:recordable=>entity,:user=>User.current,:snapshot=>cm.entity_json(entity))
  end

  def snapshot_json
    return nil if self.snapshot.nil?
    ActiveSupport::JSON.decode self.snapshot
  end

end
