require 'mkmf'

have_library('stdc++')

extension_name = 'ruby_amf_ext'
dir_config(extension_name)
create_makefile(extension_name)