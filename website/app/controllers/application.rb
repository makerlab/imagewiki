require 'net/smtp'

class Application < Merb::Controller

 # before :detect_iphone

  def detect_iphone
    if request.env["HTTP_USER_AGENT"]
      if request.env["HTTP_USER_AGENT"][/(Mobile\/.+Safari)/]
        # ignore for now
        # request.format = :iphone
      end
    end
  end

  def send_email(from_name,from_email,to_name,to_email,subject,body)
    # TODO replace with something bulkier and more of a hassle later?
    # TODO it is overspecialized to use the domain name here
    from_domain = "imagewiki.org"
    if !from_name || from_name.length < 1
      from_name = "flo"
      from_email = "flo@#{from_domain}"
    end
    begin
      message = "From: #{from_name} <#{from_email}>\n" +
                "To: #{to_name} <#{to_email}>\n" +
                "Subject: #{subject}\n" +
                "#{body}\n"
      Net::SMTP.start('localhost') do |smtp|
        smtp.send_message message, from_email, to_email
      end
    rescue
      # TODO if the email fails we can use this to filter bad users
    end
  end
 
  #####################################################################
  # common user utilities
  # TODO move to a library or slice later on or use the merbauth
  # TODO think about the pattern of rails MVC => it fails to let one concentrate roles
  #####################################################################

  def logged_in?
    return true if self.current_user
    return false
  end

  def authorized?
    # TODO improve to deal with admin areas and the like
    logged_in? || throw(:halt, :access_denied)
  end 

  def access_denied
    case content_type
    when :html
      session[:return_to] = request.uri
      redirect url(:login)
    when :xml
      headers["Status"] = "Unauthorized"
      headers["WWW-Authenticate"] = %(Basic realm="Web Password")
      self.status = 401
      render "Could not authenticate you"
    end
  end

  def is_admin?
    return true if self.current_user && self.current_user.is_admin?
    access_denied
    return false
  end

  def store_location
    session[:return_to] = request.uri
  end
    
  def redirect_back_or_default(default)
    location = session[:return_to] || default
    session[:return_to] = nil
    redirect location
  end

  def current_user
    @current_user = login_from_session if !@current_user
    @current_user = login_from_cookie if !@current_user
    return @current_user || false
  end

  def login_from_session
    user = nil
    user = User.first(:id => session[:user]) if session[:user]
    session_start(user)
  end

  def login_from_cookie
    user = nil
    user = User.first(:remember_token => cookies[:auth_token] ) if cookies[:auth_token]
    session_start(user)
  end

  def session_start(user)
    @current_user = (user.nil? || user.is_a?(Symbol)) ? nil : user
    session[:user] = (user.nil?) ? nil : user.id
    if user && user.remember_token?
      user.remember_me
      cookies[:auth_token] = {
                      :value => user.remember_token ,
                      :expires => user.remember_token_expires_at
                     }
    end
    return user || false
  end 
 
  def session_stop
    @current_user.forget_me if @current_user
    cookies.delete :auth_token
    @current_user = nil
    session[:user] = nil
  end

  #####################################################################
  # login from http auth
  # unused
  #####################################################################

  # admin area password stuff
  def get_auth_data 
    auth_data = nil
    [
      'REDIRECT_REDIRECT_X_HTTP_AUTHORIZATION',
      'REDIRECT_X_HTTP_AUTHORIZATION',
      'X-HTTP_AUTHORIZATION', 
      'HTTP_AUTHORIZATION'
    ].each do |key|
      if request.env.has_key?(key)
        auth_data = request.env[key].to_s.split
        break
      end
    end
    if auth_data && auth_data[0] == 'Basic' 
      return Base64.decode64(auth_data[1]).split(':')[0..1] 
    end 
  end

  # ask for administrative access
  def authorize
    if session["allcool"] == 1
      return true
    end
    login,password = get_auth_data
    @test = User.find_by_login(login)
    if @test && @test.authenticated?(password) # && @test.is_admin
      session["allcool"] = 1
      return true
    end
    session["allcool"] = 0
    headers["Status"] = "Unauthorized" 
    headers["WWW-Authenticate"] = 'Basic realm="Realm"'
    self.status = 401
    render "Authentication Required"
    return false
  end

  # Inclusion hook to make #current_user_model and #logged_in?
  # available as ActionView helper methods.
  # def self.included(base)
  #   base.send :helper_method, :current_user, :logged_in?
  # end

end



