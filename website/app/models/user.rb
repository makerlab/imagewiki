
require 'digest/sha1'

class User

  include DataMapper::Resource
  include DataMapper::Validate

  # facts which are similar to ordinary nodes
  property :id,                        Integer,  :serial => true
  property :title,                     Text
  property :link,                      Text
  property :description,               Text
  property :tagstring,                 Text
  property :depiction,                 Text
  property :location,                  Text
  property :lat,                       Float
  property :lon,                       Float
  property :radius,                    Float
  property :begins,                    DateTime
  property :ends,                      DateTime

  # TODO: move all of these kinds of facts to a separate hash or table?
  property :age,                       Integer
  property :sex,                       Text
 
  # TODO: formalize this numbering
  # 0 = inactive
  # 1 = normal
  # 2 = deputized in some way
  # 3 = administrator
  property :permissions,               Integer, :default => 1

  # facts specific to users
  property :login,                     Text
  property :email,                     Text
  property :firstname,                 Text
  property :lastname,                  Text
  property :crypted_password,          Text
  property :salt,                      Text
  property :remember_token,            Text
  property :remember_token_expires_at, Time
  property :created_at,                DateTime
  property :updated_at,                DateTime

  attr_accessor         :password
  attr_accessor         :password_confirmation
  validates_present     :login, :email
  validates_present     :password,                   :if => :password_required?
  validates_length      :password, :within => 4..40, :if => :password_required?
  # validates_present   :password_confirmation,      :if => :password_required?
  # validates_confirmation_of :password,              :if => :password_required?
  validates_length      :login,    :within => 3..32
  validates_length      :email,    :within => 3..100
  validates_is_unique   :login,    :email, :case_sensitive => false
  validates_format      :login,
                          :with => /^([a-z0-9_]+){0,2}[a-z0-9_]+$/i,
                          :on => :create,
                          :message => "can only contain letters and digits"
  validates_format      :email,
                          :with => /^([^@\s]+)@((?:[-a-z0-9]+\.)+[a-z]{2,})$/i, 
                          :message => "Invalid email"  
  before :save,           :encrypt_password

  def self.authenticate(login, password)
    u = User.first(:login => login) # need to get the salt
    u && u.authenticated?(password) ? u : nil
  end

  def self.encrypt(password, salt)
    Digest::SHA1.hexdigest("--#{salt}--#{password}--")
  end

  def encrypt(password)
    self.class.encrypt(password, salt)
  end

  def authenticated?(password)
    crypted_password == encrypt(password)
  end

  def remember_token?
    remember_token_expires_at && Time.now.utc < remember_token_expires_at 
  end

  def remember_me
    remember_me_for Merb::Const::WEEK * 2
  end

  def remember_me_for(time)
    remember_me_until time.from_now.utc
  end

  def remember_me_until(time)
    self.remember_token_expires_at = time
    self.remember_token = encrypt("#{email}--#{remember_token_expires_at}")
    save # (false)
  end

  def forget_me
    self.remember_token_expires_at = nil
    self.remember_token            = nil
    save # (false)
  end

  def set_new_password
    new_pass = User.random_string(10)
    self.password = self.password_confirmation = new_pass
    self.save
    return new_pass
    #Notifications.deliver_forgot_password(self.email, self.login, new_pass)
  end

  def self.random_string(len)
    #generate a random password consisting of strings and digits
    chars = ("a".."z").to_a + ("A".."Z").to_a + ("0".."9").to_a
    newpass = ""
    1.upto(len) { |i| newpass << chars[rand(chars.size-1)] }
    return newpass
  end

  def to_s; login end
  
  def is_admin?
    return self.permissions == 3
  end

  def encrypt_password
    return if password.blank?
    self.salt =Digest::SHA1.hexdigest("#{Time.now.to_s}#{login}") if new_record?
    self.crypted_password = encrypt(password)
  end

  def password_required?
    crypted_password.blank? || !password.blank?
  end

end

