require 'open_chain/entity_compare/entry_comparator'

module OpenChain; module CustomHandler; module Vandegrift; module KewillEntryComparator
  include OpenChain::EntityCompare::EntryComparator

  def accept? snapshot
    accept = super
    if accept
      accept = snapshot.recordable.try(:source_system) == Entry::KEWILL_SOURCE_SYSTEM
    end

    accept
  end
  
end; end; end; end