
require 'find'
# require 'RMagick'

require 'lib/multipart'
require 'lib/http_image_db'
require 'lib/image_db'
ImageDB.set_database("http://localhost:4444/")

IMAGEDB_FOLDER = "imagedb"
IMAGEDB_FOLDER_FULL_PATH = "public/#{IMAGEDB_FOLDER}"

USE_SIMILARITY_CACHE = false

#
# notes defines a directed acyclic graph of posts with arbitrary metadata
# rich concept of note to note relationships is also offered with labelled edges
#

class Note

  include DataMapper::Resource

  property :id,              Integer, :serial => true
  property :title,           Text
  property :link,            Text
  property :description,     Text,    :default => ""
  property :tagstring,       Text,    :default => ""
  property :depiction,       Text
  property :location,        Text,    :default => ""
  property :lat,             Float,   :default => 0
  property :lon,             Float,   :default => 0
  property :radius,          Float,   :default => 0
  property :begins,          DateTime 
  property :ends,            DateTime 
  property :created_at,      DateTime
  property :modified_at,     DateTime

  property :slug,            Text
  property :parent,          Integer 
  property :root,            Integer
  property :handler,         Text 

  property :user_id,         Integer, :default => 0
  property :perms,           Integer, :default => 0
  property :deleted,         Integer, :default => 0
  property :promoted,        Integer, :default => 0
  property :extended,        Text 
  property :nchildren,       Integer
  property :nobservers,      Integer

end

#
# note to note relationships; used for building persistent webs of relationships
# also have their own metadata but this helps for relationship specific data
# tags are also kept here since they are often used to group multiple nodes
# note 'extended' attributes are not kept here
#
class Note_Relation
  include DataMapper::Resource
  belongs_to :note
  property :id,                        Integer, :serial => true
  property :user_id,                   Integer
  property :note_id,                   Integer
  property :target_id,                 Integer
  property :kind,                      Text
  property :value,                     Text
  property :value_int,                 Text
  property :created_at,                DateTime 
  property :updated_at,                DateTime
end

#
# recent observers of a given subject
# was best done explicitly however it does make psychographic profiles harder
# if it turns out to be a problem we can conflate into the notesrelation table
# TODO consider using the relations table
#
class Note_Visitor
  include DataMapper::Resource
  belongs_to :note
  belongs_to :user
  property :id,              Integer, :serial => true
  property :note_id,         Integer
  property :user_id,         Integer
  property :modified_at,     DateTime
end

#
# formal members of a given subject
# debate here if this is the best way or if some kind of group permissions best
# right now this is the way that we know that somebody has perms on something
# TODO consider using the relations table
#
class Note_User
  include DataMapper::Resource
  belongs_to :user
  belongs_to :note
  property :user_id,         Integer
  property :group_id,        Integer
  property :note_id,         Integer
  property :role,            Text 
end

class Note

# turned off for now - anselm - jul 17 2008 - TODO fix
#
#    has n,  :users,            #  :through => :notes_users
#    has n,    :notes_users,      #  :dependent => :destroy
#    has n,    :notes_visitors,   #  :dependent => :destroy
#    has n,    :notes_relations,  #  :dependent => :destroy
#    serialize   :extended
#
 
    # this tagging concept is clumsy; use our own from scratch
    # acts_as_taggable

    # this below just confuses things so leave it off; just do it by hand.
    # acts_as_tree :order => object_id

    # we cannot validate here because link is optional
    # validates_format_of :link, :with => /^(ftp|https?):\/\/((?:[-a-z0-9]+\.)+[a-z]{2,})/

    # slugs are mandatory - can be auto-generated in save() so cannot pre-validate length here
    # validates_length_of :slug,:within => 1..64

    # slug format can still be validated even if no slug is passed
=begin
# this is annoyingly broken fix later - jan 2008 TODO
    validates_format_of :slug,
                        :with => /^([a-z0-9_-]+){0,2}[a-z0-9_-]+$/i,
                        :on => :create,
                        :message => "can only contain letters and digits"
=end

    ############################################################################
    # comment support
    ############################################################################

    def add_comment(user,comment)
      return false if !user || !comment || !comment.length
      nr = Note_Relation.new({
                   :user_id => user.id,
                   :note_id => self.id,
                   :kind => "comment",
                   :value => comment
                 })
      return nr.save
    end

    def get_comments()
      return Note_Relation.all(:note_id => self.id, :kind => "comment" )
    end

    ############################################################################
    # relations: notes have arbitrary edges that act similar to tags
    #            a relationship is something that typically connects two nodes
    #            it can also be used to store any arbitrary metadata on a node
    #            it also does our web 2.0 style tagging support or folksonomy
    ############################################################################

    # yield first relationship by user and style on this note
    def relation_get_first(user,kind)
      if user
        return Note_Relation.first(:note_id => self.id, :user_id => user.id, :kind => kind )
      else
        return Note_Relation.first(:note_id => self.id, :kind => kind )
      end
    end

    # yield all relationships by user and style on this note
    # TODO use a collect() instead
    def relation_get_all(user,kind)
      results = []
      Note_Relation.all( :note_id => self.id, :user_id => user.id, :kind => kind ).each do |r|
        results.push(r.value)
      end
      return results
    end

    # withdraw a user from having sponsored any relations on this note
    def relation_withdraw_all(user)
      Note_Relation.all(:note_id => self.id, :user_id => user.id ).destroy!
    end

    # withdraw a user from having sponsored a class of relations on this note
    def relation_withdraw_kind(user,kind)
      Note_Relation.all(:note_id => self.id, :user_id => user.id, :kind => kind ).destroy!
    end

    # rebuild a relationship; withdrawing the old one and applying the new one
    def relation_associate_specific(user,kind,value)
      relation_withdraw_kind(user,kind);
      return nil if !value
      # TODO clean the value!?
      Note_Relation.new({
                   :note_id => self.id,
                   :user_id => user.id,
                   :kind => kind,
                   :value => value.strip
                 }).save
      return nil
    end

    # rebuild a relationship; but taking a whole pile of values from a list - this effectively does tagging
    def relation_associate_specific_csv(user,kind,value)
      relation_withdraw_kind(user,kind)
      return nil if !value
      value.split(',').each do |v|
        # TODO clean the values!???
        Note_Relation.new({
                     :note_id => self.id,
                     :user_id => user.id,
                     :kind => kind,
                     :value => v.strip
                   }).save
      end
      return nil
    end

    ###########################################################################
    # treat extended variables as a hash
    # this is distinct from relationships and can be another place for metadata
    ##########################################################################

    def []=(a,b)

puts "trying to store #{a} and #{b}"
      if a && self.respond_to?(a)
        super(a,b)
      else
        self.extended = {} if !self.extended || !self.extended.is_a?(Hash)
        self.extended[a.to_s] = b
      end
    end

    def [](a) 
      if a
        return super(a) if self.respond_to?(a)
        return self.extended[a.to_s] rescue nil
      end
      return nil
    end

    ####################################################################
    # recent visitors
    ####################################################################

    def activity_remember(user)
 
      # paranoia
      return if !user
      user_id = user.id
      user_id = user_id.to_i  # TODO why???
      return if !user_id

      # If this note was unsponsored; let us make the first observer own it
      # TODO: this may cause side effects; it circuments an auth iphone issue
      self.user_id = user_id if !self.user_id || !User.first(self.user_id)
    
      # Increment number of observers
      self.nobservers = 0 if !self.nobservers
      self.nobservers = self.nobservers + 1
      self.save

      # first remove this user from having recently seen this note
      Note_Visitor.all(:user_id => user_id, :note_id => self.id ).destroy!

      # then append this user as having recently seen this note
      begin
        n = Note_Visitor.new(:user_id => user_id, :note_id => self.id, :modified_at => Time.now )
        n.save
      rescue
      end
      # then truncate the set of notes; however must truncate from the head
      # TODO not supremely elegant
      begin
        count = 64
        Note_Visitor.all(:note_id => self.id, :order => [:id.desc]).each do |x|
          count = count - 1
          if count <= 0
             x.destroy!
          end
        end
      rescue
      end
    end


    def activity_get(offset=0,limit=64)
      # return a collection of recent visitors based on the recent visitors table
      # TODO not elegant
      results = []
      Note_Visitor.all(:note_id => self.id, :order => [:id.desc] ).each do |x|
        u = User.first(:id => x.user_id )
        results << u if u
      end
      return results
    end

    ####################################################################
    # deal with users who are members/observers of a specific note
    ####################################################################

    # returns true if a given user is a member of this note - does include the sponsor!
    def is_a_member?(user_id)
      return true if user_id && self.user_id == user_id
      return user_id && Note_User.first(:user_id => user_id, :note_id => self.id )
    end

    # allows a member to join this note - a sponsor cannot join!
    def join(user_id,group=nil,role=nil)
      if !is_a_member?(user_id)
        begin
          x = Note_User.new(:user_id => user_id, :note_id => self.id )
          x.group = group.id if group
          x.role = role if role
          x.save
        rescue
          return false
        end
      end
      return true
    end

    # stop being a member of this note; TODO a sponsor cannot leave.
    def leave(user_id)
      if is_a_member?(user_id)
        begin
          Note_User.all(:note_id => self.id, :user_id => user_id ).destroy!
        rescue
          return false
        end
      end
      return true
    end

    # return a set of notes that a user is a member of. does not including notes they sponsored!
    def self.get_memberships(user_id)
      # TODO remove hardcap limit
      memberships = Array.new
      results = Note_User.all(:user_id => user_id, :order => [:id.desc], :offset => 0, :limit => 100 )
      results.each do |result|
        note = self.first(:id => result.group_id)
        @memberships << note if note
      end
      return memberships
    end

    # returns a set of user objects that are members of this note. does not include the sponsor!
    def get_members()
      # TODO remove hardcap limit
      res = Array.new
      results = Note_User.all(:note_id => self.id, :order => [id.desc], :offset => 0, :limit => 10)
      results.each do |result|
        user = User.first(:id => result.user_id)
        res << user if user
      end
      return res
    end

    # find primary sponsor associated with this note; this is distinct from membership
    def get_user()
      user = User.first(:id => self.user_id)
      if !user
        user = User.new
        user.login = "anon"
      end
      return user
    end

    # get a user name
    def get_user_name_not_null
      user = User.first(:id => self.user_id )
      return user.login if user
      return "anon"
    end

    # find name of user of this note
    def get_user_login
      user = User.first(:id => self.user_id )
      return user.login if user
      return nil
    end

    ####################################################################
    # permissions
    ####################################################################

    # set privacy levels associated with a note; this is done elsewhere currently
    def set_privacy(user=nil,level=0)
      # TODO finish and test
      # currently 0 = public, 1 = public but read only, 2 = private, 3 = private and read only
      # in all cases if you are a member you can see it
    end

    def may_view(user)
      return true
      # TODO make these operate on user only
      # return self.perms == nil || self.perms == 0 || self.perms == 1 || ( user && self.is_a_member?(user.id) )
    end

    def may_edit(user)
      return true
      # TODO fix
      # return self.perms == nil || self.perms == 0 || self.perms == 1 || ( user && self.is_a_member?(user.id) )
    end

    def may_delete(user)
      return false if !user
      return true if user && user.class == User && user.is_admin? || self.user_id == user.id
      return false
      # TODO should a more complex group and user set of privileges be defined?
    end

    ####################################################################
    # filesystem type operations
    ####################################################################

    # find roots of the filesystem
    # TODO a more efficient join for permissions please
    def self.find_roots(user=nil,offset=0,limit=100)
      candidates = Note.all(:parent => 0,:order=>[:id.desc],:offset=>offset,:limit=>limit)
      results = []
      candidates.each do |x|
        if x.may_view(user)
          results << x
        end
      end
      return results
    end

    # find children of a folder
    # TODO this is not incredibly well written - improve
    def find_children(offset=0,limit=100,newerthan=0,handler=nil)
      if !handler
        if !newerthan
          return Note.all(:parent=>self.id,:order=>[:id.desc],:offset=>offset,:limit=>limit)
        else
          return Note.all(:id.gte => newerthan, :parent => self.id,:order=>[:id.desc],:offset=>offset,:limit=>limit)
        end
      else
        if !newerthan
          return Note.all(:parent => self.id, :handler => handler, :order=>[:id.desc],:offset=>offset,:limit=>limit)
        else
          return Note.all(:id.gte > newerthan, :parent => self.id, :handler => handler, :order=>[:id.desc],:offset=>offset,:limit=>limit)
        end
      end
    end

    # find by a path such as /anselm/files/faves
    def self.find_by_tokens(user,tokens)
      return nil if !tokens
      p = 0
      n = nil
      tokens.each do |u|
        if u && u.length > 0 
          n = Note.first(:slug=>u,:parent=>p)
          return nil if !n
          p = n.id
        end
      end
      return n
    end

    # find by a path such as /anselm/files/faves; returning the best leaf and the whole path too
    def self.find_best_by_tokens(user,tokens)
      p = 0
      best = nil
      found = []
      tokens.each do |u|
        if u && u.length > 0 
          n = Note.first(:slug=>u,:parent=>p)
          return best,found if !n
          best = n
          p = n.id
          found << u
        end
      end
      return best,found
    end

    # find by a path where the path is supplied as string with '/' as separators
    def self.find_by_path(user,path)
      return nil if !path
      return self.find_by_tokens(user,path.split('/'))
    end

    # return an url mapping for this note
    def relative_url
      path = nil
      note = self
      while true
        path = "/#{note.slug}#{path}"
        return path if !note.parent
        note = Note.first(:id=>note.parent)
        return path if !note
      end
      return nil
    end

    def get_file_path
      return relative_url
    end

    # return tokens
    def relative_tokens
      path = []
      note = self
      while true
        path << note.slug
        return path.reverse if !note.parent
        note = Note.first(:id=>note.parent)
        return path.reverse if !note
      end
      return nil
    end

    # get parent as a node
    def get_parent
      note = self
      return Note.first(:id=>note.parent)
    end

    # return just the parent as an url path
    def relative_url_parent
      note = self
      return note.get_parent().relative_url
    end

    #
    # get a child by name
    #
    def Note.get_child(slug,parent = nil)
      parent_id = 0
      parent_id = parent.id if parent
      note = Note.first(:parent => parent_id, :slug => slug )
      return note
    end

    ##################################################################
    # destroy
    ##################################################################

    def destroy
      # TODO verify legality
      # destroy all relationships TODO
      # destroy all children
      # destroy files on disk
      super
    end

    ###################################################################
    # set - set properties on new or existing notes with perms
    ###################################################################

    def Note.set(note,args,user)

      # try to set a user
      user_id = 0
      user_id = user.id if user

      # scavenge an existing note for editing if possible
      if !note
        _id = 0
        begin
          _id = args["id"].to_i if args["id"]  # TODO : really?
        rescue
        end
    	note = Note.first(:id => _id) if _id > 0
        if !note
    	  note = Note.new({:user_id=>user_id})
	  note.perms = 0 # HAS TO BE SET SINCE NIL != 0
        end
      end

      # flag a general error if the user does not have edit permissions
      if !note.may_edit(user)
        note.errors.add('perm','no edit privs')
        return note
      end

      # do not let somebody elevate their privileges - TODO; may be irrational
      if !note.may_delete(user)
        args.delete(:perms)
        args.delete('perms')
      end

      # setting the user only if it is not already set 
      if !note.user_id && user
        note.user_id = user_id
      end

      # TODO consider a schema filter? not so critical with args[:note] approach
      # @crud = [ :members,'members',:depiction,'depiction',:submit,'submit',
      #        :json,'json',:user_id,'user',:referer,'referer',:id,'id',
      #        'created_at',:created_at,:_,':_',:x,'x',:y,'y',:upload,'upload',
      #        :path,'path' ]

      # set extended hash on the node where things do not match real properties
      args.each do |x,y|
        next if note.respond_to?(x)
        # next if @crud.include?(x) (we don't really need this now with args[:note] as opposed to raw args)
        x = x.to_s
        y = y.to_s
        next if !x || x.to_s.length < 1
        y = y.strip if y && y.class == "String"
        next if !y || y.to_s == '' || (y.class=="String" && y.length < 1)
        note[x] = URI.escape(y)
  	puts "Note::set() : extended accepted #{x} and #{y}"
      end

      # set parameters where they match real properties
      args.each { |x,y|
        if x && y && y.to_s.length > 0 && note.respond_to?(x)
          note.send(x.to_s+'=',y.to_s)
        end
      }

      # make parent 0 if nil because sql differentiates between 0 and nil
      self.parent = 0 if !self.parent

      # validate but do not save yet
      note.valid?

      return note

    end

    ###################################################################
    # save_finalize - save and set some properties that rely on an id
    ###################################################################

    def save_finalized

      # finalize it
      state = save

      # must assign a slug after saving
      if state && !self.slug 
        self.slug = "#{self.id}"
        state = save
      end

      # must tag after saving - make sure to destroy the note if this fails
      if state && self.id && self.tagstring
        # TODO fix tagging - we are using relationships now instead to tag
        # also ... a relation between two notes can be defined by a tag...
        # we want relationships between two notes explicitly ...
        # Note.find_by_sql("DELETE FROM notes_relations WHERE note_id = #{self.id}")
        # self.tag self.tagstring
      end

      return state
    end

    ###################################################################
    # note associated image management
    ###################################################################

    def relative_url_fragment_to_jpg
      return "/#{IMAGEDB_FOLDER}/#{self.id}.jpg"
    end

    def path_to_bmp
      return "public/#{IMAGEDB_FOLDER}/#{self.id}.bmp"
    end

    def path_to_jpg
      return "public/#{IMAGEDB_FOLDER}/#{self.id}.jpg"
    end
    
    def path_to_thumbnail
      return "public/#{IMAGEDB_FOLDER}/#{self.id}.thumb.jpg"
    end

    def save_image(args = {})

      name = args[:name] || nil
      link = args[:link] || nil
      path = args[:path] || nil
      add_to_searchable = args[:add_to_searchable] || false

      handle = nil
      if link && link.length > 0
        url = URI.parse(link)
        req = Net::HTTP::Get.new(url.path)
        res = Net::HTTP.start(url.host, url.port) do |http|
          resp = http.request(req)
          handle = File.new("scratch2",File::CREAT|File::RDWR,0644)
          if handle
            handle.binmode
            handle.sync = true
            handle.write resp.body
            handle.flush
            handle.rewind
          end
        end
      end

      if !handle && path
        handle = path[:tempfile] # File.open(path[:tempfile].path,"rb")
        #handle.binmode
      end

      # TODO image storage hierarchy
      # TODO multithreaded now breaks this!!!
      fname = "public/#{IMAGEDB_FOLDER}/#{name}"
      f = File.new("scratch",File::CREAT|File::RDWR,0644)
      f.write handle.read if f
      f.close if f
      f = nil

      # force through imagemagick from any format into jpg
      # XXX TODO fix singlethreaded
      %x[/usr/local/bin/convert scratch #{fname}.jpg]
      raise "Internal error did not save #{fname}" if !File.exist?("#{fname}.jpg")
 
      # force through imagemagick from any format into bmp
      # XXX TODO fix singlethreaded
      %x[/usr/local/bin/convert scratch #{fname}.bmp]
      raise "Internal error failed to save #{fname}" if !File.exist?("#{fname}.jpg")

      # associate depiction in url space
      depiction = relative_url_fragment_to_jpg()
      save

      save_thumbnail

      puts "model::note::add:: done building thumbnails etc"

      # add to sift database
      if add_to_searchable == true
        image_db = HTTPImageDB.new()
        image_db.add_image("#{fname}.bmp", name)
        puts "model::note::add:: done adding to db"
      end

      return true  # throws exceptions if it fails
    end

    #  we could do this later but i found this to be non performant and reliant on rmagic that itself often fails to build
    #  
    #     img = Magick::Image.read("#{v}#{e}")
    #     thumb = img[0].scale(512,400)
    #     thumb.write File.join(u,".#{name}.large.jpg")
    #     GC.start

    def save_thumbnail
      full_res_path = path_to_jpg()
      thumbnail_path = path_to_thumbnail()
      %x[/usr/local/bin/convert #{full_res_path} -strip -coalesce -resize 128x128 -quality 85 #{thumbnail_path}]
      # there were some issues with permissions; just hack past this
      %x[/bin/chmod 777 #{thumbnail_path}]
      %x[/bin/chmod 777 #{full_res_path}]
      # circumvent some memory leaks for good luck
      GC.start
    end

    def save_sift_image
      # make a depiction of the SIFT so we can see what the sucker looks like
      %x[/www/sites/imagewiki/engine/src/siftfeat -x -o #{fname}.sift #{fname}.bmp]
      # make sketch of what the SIFT looks like (JPG out is broken here too)
      %x[/www/sites/imagewiki/engine/src/siftfeat -x -m #{fname}.sift.bmp #{fname}.bmp]
      %x[/usr/local/bin/convert #{fname}.sift.bmp #{fname}.sift.jpg]
      %x[/usr/local/bin/convert -size 128x128 #{fname}.sift.jpg -strip -coalesce -resize 128x128 -quality 100 #{fname}.sift.thumb.jpg]
      # Add the image to the SIFT db.
    end

    ###################################################################
    # find similar - wrapper for various lower level comparators
    ###################################################################

    def Note.find_similar(target)
      if !USE_SIMILARITY_CACHE
        return Note.find_similar_raw(target)
      else
        return Note.find_similar_from_cache(target)
      end
    end

    ###################################################################
    # find similar raw - talk to the http comparator
    ###################################################################

    def Note.find_similar_raw(target, include_same=false)
      return [] if !target
      results = []
      image_db = HTTPImageDB.new()
      matches = image_db.match_image("public/#{IMAGEDB_FOLDER}/#{target.id}.bmp")
      return [] if !matches
      matches.each do |s|
        id = s.label
        # Filter out the target image if requested.
        if include_same == false && id == target.id
          next
        end
        score = s.score
        note = Note.first(:id => id )
        # Just in case the image DB is out of sync with our notion of
        # what notes exist, filter out nils.
	if note
          note.description = score
          note.radius = score.to_f
          results.push(note)
        end
      end
      # sort results
      results.sort! { |b,a| a.radius <=> b.radius }
      Note.memoize(target,results)
      # TODO: truncate away boring results
      results
    end

    ###################################################################
    # find_similar_older - this was a manual shell invocation - slow
    ###################################################################

    def Note.find_similar_older(target)
      # hack; compare it to itself to get a baseline expectation
      v = %x[/www/sites/imagewiki/engine/src/db-match public/#{IMAGEDB_FOLDER}/#{target.id}.sift public/#{IMAGEDB_FOLDER}/#{target.id}.sift]
      baseline = v.to_f
      results = []
      all = Note.all(:promoted => 1 )
      all.each do |x|
        v = %x[/www/sites/imagewiki/engine/src/db-match public/#{IMAGEDB_FOLDER}/#{target.id}.sift public/#{IMAGEDB_FOLDER}/#{x.id}.sift]
        v = v.to_f
        x.radius = v.to_i
        results.push(x)
        # truncate away boring results
        if v > baseline / 400
          x.radius = (v / baseline * 100).to_i
          results.push(x)
        end
      end
      # sort results
      results.sort! { |b,a| a.radius <=> b.radius }
      results
    end

    ###################################################################
    # memoize similar images for performance
    ###################################################################

    def build_similarity_cache
      similar = Note.find_similar_raw(self)
      Note.memoize(self,similar,self.user_id)
    end

    def Note.memoize(target,similar,user_id = 0)
      myself = target
      similar.each do |sim|
        id1 = myself.id
        id2 = sim.id
        # always store relationships such that the lower id is first (mandatory!)
        if id1 > id2
          id1 = sim.id
          id2 = myself.id
        end
        # do we have this relation?
        r = Note_Relation.first(:note_id => id1, :target_id => id2 )
        # create the relation?
        if !r 
          nr = Note_Relation.new()
          nr.user_id = user_id
          nr.note_id = id1
          nr.target_id = id2;
          nr.kind = "relation"
          nr.value = "#{sim.radius}"
          nr.save
        end
      end
    end

    def Note.find_similar_from_cache(target)
      results = []
      if target
        r = Note_Relation.all(:kind => 'relation', :note_id => target.id )
        r.each do |x|
          note = Note.first(:id => x.note_id)
          results.push(note) if note
        end
        r = Note_Relation.all(:kind => 'relation', :target_id => target.id )
        r.each do |x|
          note = Note.first(:id => x.target_id)
          results.push(note) if note
        end
      end
      # TODO this is really kind of sloppy
      return (Note.find_similar_raw(target)) if results.length == 0 
      return results
    end

    ###################################################################
    # various utils
    ###################################################################

    def is_searchable?
      return self.promoted == 1
    end

    def Note.verify_filesystem
      ok = []
      not_ok = []
      Note.find(:all).each do |note|
        bad = false
        path = note.path_to_bmp()
        if !FileTest.exists?(note.path_to_bmp())
          puts "Image id #{note.id} has no BMP at #{note.path_to_bmp()}"
          bad = true
        end
        if !FileTest.exists?(note.path_to_jpg())
          puts "Image id #{note.id} has no JPEG at #{note.path_to_jpg()}"
          bad = true
        end
        if !FileTest.exists?(note.path_to_thumbnail())
          puts "Image id #{note.id} has no thumbnail at #{note.path_to_thumbnail()}"
          bad = true
        end

        if bad
          not_ok << note.id
        else
          ok << note.id
        end
      end
      puts "#{ok.length} Notes ok, #{not_ok.length} not ok."
      return {"ok" => ok, "not ok" => not_ok}
    end


    def Note.regenerate_thumbnails
      Note.all.each do |note|
        note.save_thumbnail()
      end
      return true
    end

    # Synchronizes the Image database with what's in the real db
    def Note.resync_image_db
      image_db = HTTPImageDB.new()

      puts "Removing entries"
      entries = image_db.list()
      entries.each do |entry|
        puts "  Removing #{entry.label}"
        image_db.remove_image(entry.label)
      end

      puts "Adding entries"
      all = Note.all
      all.each do |note|
        if note.is_searchable?
          puts "  Adding #{note.id}"
          image_db.add_image("public/#{IMAGEDB_FOLDER}/#{note.id}.bmp", note.id)
        end
      end
      return
    end

end



