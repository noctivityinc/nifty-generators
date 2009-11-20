class Create<%= plural_model_name %> < ActiveRecord::Migration
  def self.up
    create_table :<%= plural_name %> do |t|
    <%- for attribute in attributes -%>
      t.<%= attribute.type %> :<%= attribute.name %>
    <%- end -%>
    <%- unless options[:skip_timestamps] -%>
      t.timestamps
    <%- end -%>
    <%- if options[:include_timestamps] -%>
      t.userstamps
    <%- end -%>
    end
  end
  
  def self.down
    drop_table :<%= plural_name %>
  end
end
