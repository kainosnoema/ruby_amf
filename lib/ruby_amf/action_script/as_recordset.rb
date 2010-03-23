# Simple wrapper for serizlization time. All adapters adapt the db result into an ASRecordset 
module RubyAMF
  module ActionScript
    class ASRecordset
  
      #accessible attributes for this asrecordset
      attr_accessor :total_count
  
      #the number of rows in the recordset
      attr_accessor :row_count
  
      #columns returned
      attr_accessor :column_names
  
      #the payload for a recordset
      attr_accessor :initial_data
  
      #cursor position
      attr_accessor :cursor
  
      #id of the recoredset
      attr_accessor :id
  
      #version of the recordset
      attr_accessor :version
  
      #the service name that was originally called
      attr_accessor :service_class_name
  
      #this is an optional argument., a database adapter could optionally serialize the results, instead of the AMFSerializer serializing the results
      attr_accessor :serialized_data
  
      #mark this recordset as pageable
      attr_accessor :is_pageable

      #new ASRecordset
      def initialize(row_count, column_names, initial_data)
        self.row_count = row_count
        self.column_names = column_names
        self.initial_data = initial_data
        cursor = 1
        version = 1
      end
    end
  end
end