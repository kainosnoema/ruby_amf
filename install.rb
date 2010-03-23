begin
  require 'fileutils'
  overwrite = true
  
  install_files_root = File.join( File.dirname(__FILE__), "rails_installer_files")
  
  if !File.exist?('./config/rubyamf_config.rb')
    FileUtils.copy_file( File.join(install_files_root, "rubyamf_config.rb", "./config/rubyamf_config.rb", false)
  end
  
  FileUtils.copy_file( File.join(install_files_root, "rubyamf_helper.rb","./app/helpers/rubyamf_helper.rb",false)
  FileUtils.copy_file( File.join(install_files_root, "crossdomain.xml","./public/crossdomain.xml", false)
  
  mime = true
  mime_types_file_exists = File.exists?('./config/initializers/mime_types.rb')
  mime_config_file = mime_types_file_exists ? './config/initializers/mime_types.rb' : './config/environment.rb'
  
  File.open(mime_config_file, "r") do |f|
    while line = f.gets
      if line.match(/application\/x-amf/)
        mime = false
        break
      end
    end
  end
  
  if mime
    File.open(mime_config_file,"a") do |f|
      f.puts "\nMime::Type.register \"application/x-amf\", :amf"
    end
  end
  
  route_amf_controller = true
  File.open('./config/routes.rb', 'r') do |f|
    while  line = f.gets
      if line.match("match '/rubyamf_gateway', :to => RubyAMF::Gateway") 
        route_amf_controller = false
        break
      end
    end
  end

  if route_amf_controller
    routes = File.read('./config/routes.rb')
    updated_routes = routes.gsub(/(Application.routes.draw do)/) do |s|
      "#{$1}\n  match '/rubyamf_gateway', :to => RubyAMF::Gateway\n"
    end
    File.open('./config/routes.rb', 'w') do |file|
      file.write updated_routes
    end
  end
  
rescue Exception => e
  puts "ERROR INSTALLING RUBYAMF: " + e.message
end