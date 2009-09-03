Merb.logger.info("Compiling routes...")

Merb::Router.prepare do |r|

  r.resources :notes
  r.resources :users

  r.match('/').to(:controller => 'site', :action =>'index')

  r.match('/login').to(       :controller  => 'users', :action =>'signin')
  r.match('/signin').to(      :controller  => 'users', :action =>'signin')
  r.match('/logout').to(      :controller  => 'users', :action =>'signout')
  r.match('/signout').to(     :controller  => 'users', :action =>'signout')
  r.match('/logup').to(       :controller  => 'users', :action =>'signup')
  r.match('/signup').to(      :controller  => 'users', :action =>'signup')
  r.match('/forgot').to(      :controller  => 'users', :action => 'forgot')
  r.match('/change').to(      :controller  => 'users', :action => 'change')
  r.match('/invite').to(      :controller  => 'users', :action => 'invite')
  r.match('/participants').to(:controller  => 'users', :action => 'index' )

  r.match('/help').to(    :controller => 'site',    :action => 'help' )
  r.match('/about').to(   :controller => 'site',    :action => 'about' )
  r.match('/ispy').to(    :controller => 'site',    :action => 'ispy' )

  r.match('/search').to(  :controller => 'notes',   :action => 'search' )
  r.match('/advanced').to(:controller => 'notes',   :action => 'advanced' )
  r.match('/add').to(     :controller => 'notes',   :action => 'add' )
  r.match('/added').to(   :controller => 'notes',   :action => 'added' )
  r.match('/edit/:id').to(    :controller => 'notes',   :action => 'edit' )
  r.match('/similar/:id').to( :controller => 'notes',   :action => 'similar' ).name(:similar)
  r.match('/promote').to( :controller => 'notes',   :action => 'promote' ).name(:promote)
  r.match('/askbest/:id').to( :controller => 'notes',   :action => 'askbest' )
  r.match('/searches').to(:controller => 'notes',   :action => 'searches'  )
  r.match('/recent').to(  :controller => 'notes',   :action => 'recent' )
  r.match('/list').to(    :controller => 'notes',   :action => 'list' )
  r.match('/map').to(     :controller => 'notes',   :action => 'map' )
  r.match('/comment').to( :controller => 'notes',   :action => 'comment' )

  r.match('/services/upload').to(:controller => 'emails',   :action => 'services' )

  r.default_routes

end

