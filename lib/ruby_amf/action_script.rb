$:.unshift File.dirname(__FILE__)

# actionscript Fault objects
require 'action_script/as_fault'
require 'action_script/as3_fault'

# actionscript recordset. all adapters adapt the db result into an ASRecordset
require 'action_script/as_recordset'