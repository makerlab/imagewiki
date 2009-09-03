# Go to http://wiki.merbivore.com/pages/init-rb

#require 'rubygems'
#require 'data_objects'
#require 'do_postgres'
 
require 'config/dependencies.rb'
 
use_orm :datamapper
use_test :rspec
use_template_engine :erb

dependency "merb_helpers"
dependency "merb-assets"
dependency "merb_has_flash"

# Merb::Config[:fork_for_class_load] = false
 
Merb::Config.use do |c|
  c[:use_mutex] = false
  c[:session_store] = 'cookie'  # can also be 'memory', 'memcache', 'container', 'datamapper
  
  # cookie session store configuration
  c[:session_secret_key]  = '9e47e032467279b747db4d2a2aae0ddef4b353f6'  # required for cookie session store
  c[:session_id_key] = '_imagewiki_session_id' # cookie session id key, defaults to "_session_id"
end
 
Merb::BootLoader.before_app_loads do
  # This will get executed after dependencies have been loaded but before your app's classes have loaded.
end
 
Merb::BootLoader.after_app_loads do
  # This will get executed after your app's classes have been loaded.
end
