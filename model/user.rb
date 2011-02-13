require 'model/connection_manager'
require 'digest/sha1'

class String
  def self.random_chars( length )
    chars = ('a'..'z').to_a + ('A'..'Z').to_a + ('0'..'9').to_a
    return (0...length).map{ chars[Kernel.rand(chars.length)] }.join
  end
end

class User
  def self.find(key)
    key = key.to_s.downcase

    data = ConnectionManager.connection[:users][key]

    return nil if data.nil?
    return (User.new key, data)
  end

# Class
  def data
    return {
      :username => @key,
      :display_name => self.display_name,
      :email => self.email,
      :forms => self.forms.map{ |form| form.data }
    }
  end

  def self.create(data)
    key = data[:username].downcase
    pepper = Time.now.to_f.to_s

    ConnectionManager.connection[:users][key] = {
      :display_name => data[:username],
      :email => data[:email],
      :pepper => pepper,
      :password => (User.hash_password data[:password], pepper),
      :forms => nil
    }

    return (User.find key)
  end

  def update(data)
    self.email = data[:email] unless data[:email].nil?
    self.password = data[:password] unless data[:password].nil?
  end

  def delete!
    ConnectionManager.connection[:users][@key] = nil
  end

  def save
    ConnectionManager.connection[:users][@key] = @data
  end

  def ==(other)
    return false unless other.is_a? User
    return other.username == @key
  end

# Fields
  def username
    return @key
  end

  def display_name
    return @data['display_name']
  end

  def password
    return @data['password']
  end
  def password=(plaintext)
    @data['password'] = (User.hash_password plaintext, @data['pepper'])
  end

  def email
    return @data['email']
  end
  def email=(email)
    @data['email'] = email
  end

  def forms(get_form_data = false)
    return [] if @data['forms'].nil?
    return (@data['forms'].split ',').map{ |form_id| Form.find(form_id, get_form_data) }
  end
  def add_form(form)
    if @data['forms'].nil? || @data['forms'].empty?
      @data['forms'] = form.id
    elsif !((@data['forms'].split ',').include? form.id)
      @data['forms'] += ",#{form.id}"
    end
  end

  def is_admin?
    return @data['admin']
  end
  def admin=(is_admin)
    if is_admin
      @data['admin'] = is_admin
    else
      @data.delete('admin')
    end
  end

# Other
  def authenticate?(plaintext)
    return ((User.hash_password plaintext, @data['pepper']) == self.password)
  end

  def reset_password!
    new_password = (String.random_chars 10)
    self.password = new_password
    return new_password
  end

private
  def initialize(key, data)
    @key, @data = key, data
  end

  def self.hash_password(plaintext, pepper)
    return (Digest::SHA1.hexdigest "--[#{plaintext}]==[#{pepper}]--")
  end
end

