class OpenChain::ProjectDeliverableProcessor
  def run_schedulable opts_hash={}
    send_hash = {}
    send_hash = fill_hash_values(send_hash)
    create_emails_from_hash(send_hash)
    send_hash # for easier testing
  end

  def fill_hash_values user_pd_hash
    # Go through PDs and make a hash in the form {user_id => [PDx.id, PDy.id, ...], ...}
    ProjectDeliverable.incomplete.not_closed.where(priority: :high).each do |pd|
      assigned_user_id = pd.assigned_to.id
      user_pd_hash = add_to_hash(user_pd_hash, assigned_user_id, pd)
    end
    user_pd_hash
  end

  def add_to_hash user_pd_hash, user_id, pd
    # Create a new key/value pair if the key doesn't exist; otherwise, extend the value list
    if user_pd_hash[user_id] == nil
      user_pd_hash.merge!(user_id => [pd])
    else
      user_pd_hash[user_id] = user_pd_hash[user_id].push(pd)
    end
    user_pd_hash
  end

  def create_emails_from_hash user_pd_hash
    # For each user ID key, notify them about the PD's with an ID in value
    user_pd_hash.each do |key, value|
      user = User.find(key)
      pds_for_user = []
      value.each { |v| pds_for_user << v }
      OpenMailer.send_high_priority_tasks(user, pds_for_user).deliver_now
    end
  end
end