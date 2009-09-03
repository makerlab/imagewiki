require 'net/http'

class Notes < Application

  # provides :xml, :yaml, :js

  before :set_note_and_user
  before :logged_in, :only => %w[ add update destroy ]

private

  def logged_in
    return self.current_user || nil
  end

  def set_note_and_user
    @current_user = self.current_user || nil
    @note = nil
    if params[:id] && params[:id].to_i > 0
      # TODO there is bug in rails where /note/list is interpreted
      #       as action = "" and id = list ... sigh.
      @note = Note.find_by_tokens(@current_user,params[:id])
      @note = Note.first(:id => params[:id]) if !@note
    end
    @permitted = true
  end

public

  def index
    render
  end

  def list
    render
  end

  def searches
    @promoted = 0
    render
  end

  def map
    only_provides :html
    render
  end

  def comment
    only_provides :html
    if @note && @current_user && request.post?
      @note.add_comment(@current_user,params[:comments] )
      redirect url(:note,@note) 
      return ""
    end
    return "failed"
  end

  def show
    raise NotFound unless @note
    @note.activity_remember(self.current_user) if @note
    render :show
  end

  def add
    only_provides :html
    @note = Note.new
    render
  end

  def edit
    only_provides :html
    render
  end

  def advanced
    only_provides :html
    @note = Note.new
    render
  end

  def added
    @note = Note.set(@note,params[:note],@current_user)
    @note.promoted = 1 if @note
    if !@note.save_finalized
      render :add
      return
    end
    success = false
    if params[:note][:depiction]
       success = @note.save_image( :name => "#{@note.id}", 
                      :link => params[:note][:link],
                      :path => ( params[:note][:depiction] ),
                      :add_to_searchable => true
                    )
    else
       # actually if we are modifying an existing note then we're ok; don't freak out.
       success = true if @note.depiction && @note.depiction.length > 1
    end
    if !success
      # destroy note? TODO
      flash[:notice] = 'Internal error saving file'
      render :add
      return " "
    end
    send_email(nil,nil,nil,"imagewiki@googlegroups.com",
      "A new image added at #{@note.created_at}",
      "#{@note.title} \nSee http://imagewiki.org/notes/#{@note.id} for more.")
    flash[:notice] = 'Successfully updated.'
    redirect url(:note, @note) 
    return " "
  end

  def search
    @note = Note.new
    return render if !params[:note]
    @note = Note.set(@note,params[:note],@current_user)
    @note.promoted = 0 if @note
    if !@note.save_finalized
      redirect url(:search, @note)
      return " "
    end
    success = @note.save_image( :name => "#{@note.id}", 
                      :link => params[:note][:link],
                      :path => ( params[:note][:depiction] ),
                      :add_to_searchable => false
                    )
    if !success
      # destroy note? TODO
      flash[:notice] = 'Internal error saving file'
      render :search
      return " "
    end
    show_best_results(@note)
  end

  def show_best_results(note)
    # handle various kinds of displays depending on similar matches 
    @note = note
    @results = Note.find_similar(@note)
    if(@results.length > 0)
      # we are not sure about what to display designwise
      # so i am letting many choices exist for now
      if( params[:commit] == "I'm feeling lucky!")
        redirect "/show/#{@results[0].id}"
        return " "
      else
        render_style = 2  # on the web lets use this style
        if render_style == 1
          redirect url("/askbest/#{@note.id}")
          return " "
        end
        if render_style == 2
          # TODO: this should really only show up if there is ambiguity
          redirect "/similar/#{@note.id}"
          return " "
        end
        if render_style == 3
          redirect url("show/#{@note.id}")
          return " "
        end
      end
    else
      # if no results then offer to add
      redirect url("promote/#{@note.id}")
    end
  end

  def promote
    display @note
  end

  def recent
    render
  end

  def similar
    display @note
  end

  def destroy
    if !@note.may_delete(@current_user) || !@note.destroy
#      @note.errors.each { |k.v| @errors = "#{k}=#{v})" }
      flash[:warning] = "Destroy unsuccessful due to #{@errors}"
    end
    redirect url("/")
  end

end
