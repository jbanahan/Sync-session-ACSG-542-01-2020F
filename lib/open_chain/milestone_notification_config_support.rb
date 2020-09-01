require 'open_chain/custom_handler/generator_315/tradelens/entry_315_tradelens_generator'

module OpenChain; module MilestoneNotificationConfigSupport

  def self.included(base)
    base.include InstanceMethods
  end

  module InstanceMethods
    def event_list user, module_type
      EventLister.new(user, module_type).event_list
    end
  end

  # The purpose of this wrapper is to prevent eager evaluation of CoreModule methods
  class DataCrossReferenceKeySelector
    include parent

    def initialize module_type
      @module_type = module_type
    end

    def to_a
      @data ||= event_list(nil, @module_type).map { |f| [f[:label], f[:mfid]] } # rubocop:disable Naming/MemoizedInstanceVariableName
    end
  end

  # This one is for symmetry
  class DataCrossReferenceValueSelector
    def initialize module_type
      @module_type = module_type
    end

    def to_a
      endpoint_labels_meth = "#{@module_type.underscore}_endpoint_labels".to_sym
      end_point_labels = OpenChain::CustomHandler::Generator315::Tradelens::Entry315TradelensGenerator.public_send endpoint_labels_meth
      end_point_labels.map { |ep, label| [label, ep] }
    end
  end

  class EventLister
    attr_reader :user, :module_type

    def initialize user, module_type
      @user = user
      @module_type = module_type
    end

    def event_list
      @filter_data ||= init_filters

      cm = CoreModule.by_class_name(module_type)
      fields = []
      if cm
        model_fields = cm.model_fields(user) { |mf| ([:date, :datetime].include? mf.data_type.to_sym) }
        model_fields.each_value do |mf|
          fields << {field_name: mf.field_name.to_s,
                     mfid: mf.uid.to_s,
                     label: "#{mf.label} (#{mf.field_name}) - #{mf.data_type.to_s == 'datetime' ? 'Datetime' : 'Date'}",
                     datatype: mf.data_type.to_s,
                     filters: filter_list(mf.uid.to_s)}
        end
        fields = fields.sort {|x, y| x[:label] <=> y[:label]}
      end

      fields
    end

    private

    def init_filters
      filters = {}
      filters[:tradelens] = tradelens_mfids
      filters
    end

    def filter_list uid
      filters = []
      @filter_data.each { |filter_type, uid_list| filters << filter_type.to_s if uid_list.include?(uid) }
      filters
    end

    def tradelens_mfids
      if module_type
        xref_type = "tradelens_#{module_type.downcase}_milestone_fields"
        DataCrossReference.where(cross_reference_type: xref_type).pluck :key
      else
        []
      end
    end
  end

  private_constant :EventLister

end; end
