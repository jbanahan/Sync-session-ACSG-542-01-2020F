class SnapshotDescriptor

  attr_reader :entity_class, :parent_association, :children, :json_writer

  def initialize entity_class, parent_association: nil, writer: nil, children: nil
    @entity_class = entity_class
    # < is an inheritance operator
    raise ArgumentError, "entity_class argument must extend ActiveRecord.  It was #{entity_class.name}." unless !@entity_class.nil? && @entity_class < ActiveRecord::Base

    @parent_association = parent_association
    @json_writer = writer.presence || SnapshotWriter.new
    raise ArgumentError, 'writer argument must respond to entity_json message.' unless @json_writer.respond_to?(:entity_json)
    @children = children
    raise ArgumentError, 'children must all be SnapshotDescriptor instances.' if Array.wrap(children).any? {|c| !c.is_a?(SnapshotDescriptor)}
  end

  def entity_json entity
    return "" if entity.nil?
    raise ArgumentError, "Invalid entity. Expected #{@entity_class.name} but received #{entity.class.name}." unless valid_entity?(entity)
    @json_writer.entity_json self, entity
  end

  def self.for parent_class, child_hashes, writer: nil, descriptor_repository: nil
    descriptor = root_make_descriptors_for parent_class, child_hashes: child_hashes, writer: writer, descriptor_repository: descriptor_repository
    if descriptor_repository
      descriptor_repository[parent_class] = descriptor
    end

    descriptor
  end

  private

    def valid_entity? entity
      entity.class.name == @entity_class.name
    end

    def self.root_make_descriptors_for parent_class, association_name: nil, child_hashes: nil, writer: nil, descriptor_repository: nil
      children = []
      if child_hashes && child_hashes.is_a?(Hash)
         child_hashes.each_pair do |parent_association, values|
          if values[:children].is_a?(Hash)
            children << root_make_descriptors_for(values[:type], association_name: parent_association, child_hashes: values[:children], descriptor_repository: descriptor_repository)
          else
            if values[:type]
               children << SnapshotDescriptor.new(values[:type], parent_association: parent_association)
            elsif values[:descriptor]
              descriptor = descriptor_repository[values[:descriptor]]

              if descriptor.nil?
                raise "No existing descriptor could be found from repository for #{parent_association} in #{parent_class}"
              end

              children << SnapshotDescriptor.new(descriptor.entity_class, parent_association: parent_association, children: descriptor.children)
            else
              children << SnapshotDescriptor.new(values[:type], parent_association: parent_association)
            end

          end
        end
      end

      SnapshotDescriptor.new(parent_class, parent_association: association_name, children: children, writer: writer)
    end
    private_class_method :root_make_descriptors_for

end