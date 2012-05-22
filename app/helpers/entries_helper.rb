module EntriesHelper
  def secure_link entry, user
      return "" unless user.sys_admin?
      sec_url = entry.last_file_secure_url
      return "" unless sec_url
      return content_tag('div', content_tag('b',"Integration File:") + " " + link_to(entry.last_file_path.split("/").last, sec_url)).html_safe
  end
end
