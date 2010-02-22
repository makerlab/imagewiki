# Filters added to this controller apply to all controllers in the application.
# Likewise, all the methods added will be available for all controllers.

require "lib/dynamapper/dynamapper.rb"

class ApplicationController < ActionController::Base
  helper :all
  helper_method :current_user_session, :current_user
  filter_parameter_logging :password, :password_confirmation

  before_filter :map_start


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



  def account_path
     return "/users/#{current_user.login}" if current_user
     return "/users"
  end
  
  def map_start
    @map = Dynamapper.new(:apikey => SETTINGS[:googlemaps], :height => "340px" )
    @map.center(37.44,-122.16,9);
  end

  def verify_member
    if current_user == nil
      flash[:notice] = "Please signup or login"
      redirect_to "/signup"
      return false
    end
    return true
  end
 
  def verify_powers
    if current_user == nil
      flash[:notice] = "Please signup or login now"
      redirect_to "/signin"
      return false
    end
	return true
  end

  private
    def current_user_session
      return @current_user_session if defined?(@current_user_session)
      @current_user_session = UserSession.find
    end
    
    def current_user
      return @current_user if defined?(@current_user)
      @current_user = current_user_session && current_user_session.record
    end
    
    def require_user
      unless current_user
        store_location
        flash[:notice] = "You must be logged in to access this page"
        redirect_to new_user_session_url
        return false
      end
    end

    def require_no_user
      if current_user
        store_location
        flash[:notice] = "You must be logged out to access this page"
        redirect_to "/users/#{current_user.login}"
        return false
      end
    end
    
    def require_admin
      unless current_user && current_user.admin?
        store_location
        flash[:error] = "You must be an admin to access this page." 
        redirect_to new_user_session_url
      end 
    end    

    def store_location
      session[:return_to] = request.request_uri
    end
    
    def redirect_back_or_default(default)
      redirect_to(session[:return_to] || default)
      session[:return_to] = nil
    end
end
