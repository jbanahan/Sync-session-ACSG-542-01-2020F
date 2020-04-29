# Takes a name with an array of names and adds a unique "(COPY n)" suffix if the first name matches any member of the array.

module OpenChain; module NameIncrementer

  def self.increment old_name, existing_names
    old_base_name = strip_suffix(old_name)
    num = existing_names.map { |name| {full_name: name, base_name: strip_suffix(name)} }
                        .select { |hsh| old_base_name == hsh[:base_name] }
                        .map { |hsh|
                          suffix = hsh[:full_name].slice(/ \(COPY.*\)/)
                          if suffix
                            (suffix.match(/\d+/)[0]).to_i rescue 1
                          else
                            0
                          end
                        }
                        .max

    old_base_name + create_suffix(num)
  end

  private

  def self.strip_suffix name
    name.gsub(/ \(COPY.*\)/, "").strip || name.strip
  end

  def self.create_suffix num
    case num
    when nil
      ""
    when 0
      " (COPY)"
    else
      " (COPY #{num + 1})"
    end
  end

end; end
