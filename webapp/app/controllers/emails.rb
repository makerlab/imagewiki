# require 'tmail'

class Emails < Application

  def services
    @photoid = 0
    @user = nil
    @note = nil
puts "*********************"
p params
puts "*******************"

    # find the user from their auth token...
    # TODO we need a real security system
    # TODO note the iphoneclient has a bug where it uses the tags not userid
    begin
      nick = params["userid"]
      nick = nick.downcase if nick
      @user = User.find_by_login(nick)
      nick = params["tags"]
      nick = nick.downcase if nick
      @user = User.find_by_login(nick) if !@user
    rescue
    end
   
    # TODO we need something here as well; not a fallback to me 
    @user = User.find_by_login("anselm") if @user == nil 

    # just turn off authorize for now - TODO remove
    session["allcool"] = 1

    # attempt to save the users file
    # TODO save location
    if @user != nil
      info = {}
      info["title"] = "iphone upload"
      info["description"] = "This image was sent from an iphone."
      info["depiction"] = params["photo"]
      info["perms"] = 0  # mark as a search not an add object.
      @note = Note.set(nil,info,@user)
      @note.perms = 0 if @note
      if @note.save
        @photoid = @note.id
      end
    end
    # dump the xml manually cuz rails sucks
    response.headers["Content-Type"] = "text/xml"
    #render :layout => false
    render :text => "<?xml version=\"1.0\" encoding=\"utf-8\" ?>\n<rsp stat=\"ok\" photoid=\"http://imagewiki.org/notes/addorsearch/#{@photoid}\"><photoid>#{@photoid}</photoid></rsp>"
    begin
      send_email(nil,nil,nil,"imagewiki@googlegroups.com",
                "ImageWiki notification: iPhone search by #{@user.login} (img id #{@photoid})",
                 "Please see user history at http://imagewiki.org/users/#{@user.login} or image details at http://imagewiki.org/notes/#{@photoid}")
    rescue
    end
  end

  def index

    return if !params[:email]

    # parse the email
    email = TMail::Mail.parse(params[:email])
    return if !email
    return if !email.from || !email.from.length

    sender = email.from[0]
    subject = email.subject
    body = email.body

    @user = User.find_by_email(sender)
    @user = User.find_by_email("anselm@gmail.com") if !@user
    if !@user
      send_email(nil,nil,nil,sender,"Could not find your email","Failed to find email #{sender}")
      send_email(nil,nil,nil,"imagewiki@googlegroups.com","Invalid email address from #{sender}","FYI")
      return
    end

    # we are only interest in mail with attachments?
    if !email.has_attachments?
      send_email(nil,nil,nil,sender,"Image request missing","Please submit an image as well")
      send_email(nil,nil,"imagewiki@googlegroups.com",nil,"An email with no attachment?","FYI")
    end

    # peek at the attachments
    @attachment = nil
    begin
      counter = 0
      email.attachments.each do |attach|
        @attachment = attach
        counter = counter + 1
        #fp =File.open("/tmp/user_image_#{@user.id}_#{counter}",File::CREAT|File::TRUNC|File::WRONLY,0777)
        #fp.write(attach.read)
        #fp.close
      end
    rescue
      send_email(nil,nil,nil,sender,"Internal problem #23 adding image","Sorry, logged for admins")
      send_email(nil,nil,nil,"imagewiki@googlegroups.com","Error #23 adding image for #{sender}","FYI")
      return
    end

    # we are only interest in mail with attachments?
    if !@attachment
      send_email(nil,nil,nil,sender,"Image request missing","Please submit an image as well")
      send_email(nil,nil,"imagewiki@googlegroups.com",nil,"An email with no attachment?","FYI")
    end

    # add request? 
    if subject != nil && subject[0..2].downcase == "add"
      info = {}
      info["title"] = subject[4..-1]
      info["description"] = ""
      info["depiction"] = @attachment
      info["perms"] = 128  # mark as an add object not a search
      @note = Note.set(nil,info,@user)
      @note.perms = 128 if @note
      if @note.save
        send_email(nil,nil,nil,sender,"Added your image","Added your image #{@note.id} to the system")
        send_email(nil,nil,nil,"imagewiki@googlegroups.com",
                               "ImageWiki notification: Added an image for #{sender}",
                               "A user has added an image please see image history")
      else
        send_email(nil,nil,nil,sender,"Internal problem #24 adding image","Sorry, logged for admins")
        send_email(nil,nil,nil,"imagewiki@googlegroups.com","Error #24 adding image for #{sender}","FYI")
      end
      return
    end

    # search also saves
    info = {}
    info["depiction"] = @attachment
    info["title"] = subject
    info["description"] = "a search request from #{sender}"
    @note = Note.set(nil,info,@user)
    if @note.save
      block = "You submitted this search image <a href='http://imagewiki.org/notes/#{@note.id}'>http://imagewiki.org/notes/#{r.id}</a>"
      @results = Note.find_similar(@note)
      @results.each do |r|
        s = "See <a href='http://imagewiki.org/notes/#{r.id}'>http://imagewiki.org/notes/#{r.id}</a>"
        block = "#{block}#{s}\n"
      end
      # @note.destroy
      send_email(nil,nil,nil,sender,"Your image search results",block)
      send_email(nil,nil,nil,"imagewiki@googlegroups.com","Handled search for #{sender}",block)
    else
      send_email(nil,nil,nil,sender,"Internal problem #25 searching image","Sorry, logged for admins")
      send_email(nil,nil,nil,"imagewiki@googlegroups.com","Error #25 searching image for #{sender}","FYI")
    end

  end

end
