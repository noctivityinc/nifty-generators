class <%= plural_class_name %>Controller < ApplicationController
  before_filter :get_<%=singular_name %>, :except => [:index, :new, :create] 
  <%= controller_methods :actions %>
  
  private 
  
    def get_<%=singular_name %>
      @<%= singular_name %> = <%= class_name %>.find_by_id(params[:id])
    end
end
