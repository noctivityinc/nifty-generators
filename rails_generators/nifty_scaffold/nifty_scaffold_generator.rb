class NiftyScaffoldGenerator < Rails::Generator::Base
  attr_accessor :name, :namespace, :attributes, :controller_actions

  def initialize(runtime_args, runtime_options = {})
    super
    usage if @args.empty?

    @name = @args.first
    @namespace, @name = @name.split('::') if @name =~ /::/ # => handle namespaces

    @controller_actions = []
    @attributes = []

    @args[1..-1].each do |arg|
      if arg == '!'
        options[:invert] = true
      elsif arg.include? ':'
        @attributes << Rails::Generator::GeneratedAttribute.new(*arg.split(":"))
      else
        @controller_actions << arg
        @controller_actions << 'create' if arg == 'new'
        @controller_actions << 'update' if arg == 'edit'
      end
    end

    @controller_actions.uniq!
    @attributes.uniq!

    if options[:invert] || @controller_actions.empty?
      @controller_actions = all_actions - @controller_actions
    end

    if @attributes.empty?
      options[:skip_model] = true # default to skipping model if no attributes passed
      if model_exists?
        model_columns_for_attributes.each do |column|
          @attributes << Rails::Generator::GeneratedAttribute.new(column.name.to_s, column.type.to_s)
        end
      else
        @attributes << Rails::Generator::GeneratedAttribute.new('name', 'string')
      end
    end

    # make haml default
    options[:haml] = true unless options[:erb]
  end

  def manifest
    record do |m|
      unless options[:skip_model]
        m.directory "app/models"
        m.template "model.rb", "app/models/#{singular_name}.rb"
        unless options[:skip_migration]
          if use_namespace?
            m.migration_template "migration.rb", "db/migrate", :migration_file_name => "create_#{namespace}_#{plural_name}"
          else
            m.migration_template "migration.rb", "db/migrate", :migration_file_name => "create_#{plural_name}"
          end
        end

        if rspec?
          m.directory "spec/models"
          m.template "tests/#{test_framework}/model.rb", "spec/models/#{singular_name}_spec.rb"
          m.directory "spec/fixtures"
          m.template "fixtures.yml", "spec/fixtures/#{plural_name}.yml"
        else
          m.directory "test/unit"
          m.template "tests/#{test_framework}/model.rb", "test/unit/#{singular_name}_test.rb"
          m.directory "test/fixtures"
          m.template "fixtures.yml", "test/fixtures/#{plural_name}.yml"
        end
      end

      unless options[:skip_controller]
        m.directory "app/controllers#{namespace_dir}"
        m.template "controller.rb", "app/controllers#{namespace_dir}/#{plural_name}_controller.rb"

        m.directory "app/helpers#{namespace_dir}"
        m.template "helper.rb", "app/helpers#{namespace_dir}/#{plural_name}_helper.rb"

        m.directory "app/views#{namespace_dir}/#{plural_name}"
        controller_actions.each do |action|
          if File.exist? source_path("views/#{view_language}/#{action}.html.#{view_language}")
            m.template "views/#{view_language}/#{action}.html.#{view_language}", "app/views#{namespace_dir}/#{plural_name}/#{action}.html.#{view_language}"
          end
        end

        if form_partial?
          m.template "views/#{view_language}/_form.html.#{view_language}", "app/views#{namespace_dir}/#{plural_name}/_form.html.#{view_language}"
        end

        m.route_namespaced_resources namespace, plural_name

        if rspec?
          m.directory "spec/controllers#{namespace_dir}"
          m.template "tests/#{test_framework}/controller.rb", "spec/controllers#{namespace_dir}/#{plural_name}_controller_spec.rb"
        else
          m.directory "test/functional#{namespace_dir}"
          m.template "tests/#{test_framework}/controller.rb", "test/functional#{namespace_dir}/#{plural_name}_controller_test.rb"
        end

        unless options[:skip_javascript]
          m.directory "public/javascripts/controllers#{namespace_dir}"
          File.open("public/javascripts/controllers#{namespace_dir}/#{plural_name}.js", 'a') {|f| f.write("") }
        end
      end
    end
  end

  def namespace_dir
    "/#{namespace}" if use_namespace?
  end

  def form_partial?
    actions? :new, :edit
  end

  def all_actions
    %w[index show new create edit update destroy]
  end

  def action?(name)
    controller_actions.include? name.to_s
  end

  def actions?(*names)
    names.all? { |n| action? n.to_s }
  end

  def use_namespace?
    !namespace.blank?
  end

  def namespace_path
    if use_namespace?
      "[:#{namespace}, #{singular_name}]"
    else
      singular_name
    end
  end

  def singular_path
    if use_namespace?
      "#{namespace}_#{singular_name}"
    else
      singular_name
    end
  end

  def plural_path
    if use_namespace?
      "#{namespace}_#{plural_name}"
    else
      plural_name
    end
  end

  def form_path
    if use_namespace?
      "[:#{namespace}, @#{singular_name}]"
    else
      "@#{singular_name}"
    end
  end

  def singular_name
    name.underscore
  end

  def plural_name
    name.underscore.pluralize
  end

  def class_name
    name.camelize
  end

  def plural_class_name
    if use_namespace?
      "#{namespace.camelize}::#{plural_name.camelize}"
    else
      plural_name.camelize
    end
  end

  def plural_model_name
    if use_namespace?
      "#{namespace.camelize}#{plural_name.camelize}"
    else
      plural_name.camelize
    end
  end

  def controller_methods(dir_name)
    controller_actions.map do |action|
      read_template("#{dir_name}/#{action}.rb")
    end.join("  \n").strip
  end

  def render_form
    if form_partial?
      if options[:haml]
        "= render :partial => 'form'"
      else
        "<%= render :partial => 'form' %>"
      end
    else
      read_template("views/#{view_language}/_form.html.#{view_language}")
    end
  end

  def action_col_span
    x = 0
    x += 1 if action? :show
    x += 1 if action? :edit
    x += 1 if action? :destroy
    x
  end

  def items_path(suffix = 'path')
    if action? :index
      if use_namespace?
        "#{namespace}_#{plural_name}_#{suffix}"
      else
        "#{plural_name}_#{suffix}"
      end
    else
      "root_#{suffix}"
    end
  end

  def item_path(suffix = 'path')
    if action? :show
      if use_namespace?
        "[:#{namespace}, @#{singular_name}]"
      else
        "@#{singular_name}"
      end
    else
      items_path(suffix)
    end
  end

  def item_path_for_spec(suffix = 'path')
    if action? :show
      "#{singular_name}_#{suffix}(assigns[:#{singular_name}])"
    else
      items_path(suffix)
    end
  end

  def item_path_for_test(suffix = 'path')
    if action? :show
      "#{singular_name}_#{suffix}(assigns(:#{singular_name}))"
    else
      items_path(suffix)
    end
  end

  def model_columns_for_attributes
    class_name.constantize.columns.reject do |column|
      column.name.to_s =~ /^(id|created_at|updated_at)$/
    end
  end

  def rspec?
    test_framework == :rspec
  end

  protected

  def view_language
    options[:haml] ? 'haml' : 'erb'
  end

  def test_framework
    options[:test_framework] ||= default_test_framework
  end

  def default_test_framework
    File.exist?(destination_path("spec")) ? :rspec : :testunit
  end

  def route_namespaced_resources(namespace, *resources)
    resource_list = resources.map { |r| r.to_sym.inspect }.join(', ')
    sentinel = 'ActionController::Routing::Routes.draw do |map|'
    logger.route "#{namespace}.resources #{resource_list}"
    unless options[:pretend]
      gsub_file 'config/routes.rb', /(#{Regexp.escape(sentinel)})/mi do |match|
        "#{match}\n  map.namespace(:#{namespace}) do |#{namespace}|\n     #{namespace}.resources #{resource_list}\n  end\n"
      end
    end
  end

  def gsub_file(relative_destination, regexp, *args, &block)
    path = destination_path(relative_destination)
    content = File.read(path).gsub(regexp, *args, &block)
    File.open(path, 'wb') { |file| file.write(content) }
  end

  def add_options!(opt)
    opt.separator ''
    opt.separator 'Options:'
    opt.on("--skip-model", "Don't generate a model or migration file.") { |v| options[:skip_model] = v }
    opt.on("--skip-migration", "Don't generate migration file for model.") { |v| options[:skip_migration] = v }
    opt.on("--skip-timestamps", "Don't add timestamps to migration file.") { |v| options[:skip_timestamps] = v }
    opt.on("--skip-controller", "Don't generate controller, helper, or views.") { |v| options[:skip_controller] = v }
    opt.on("--skip-javascript", "Don't generate a blank javascript file for the controller") { |v| options[:skip_javascript] = v }
    opt.on("--invert", "Generate all controller actions except these mentioned.") { |v| options[:invert] = v }
    opt.on("--haml", "Generate HAML views instead of ERB.") { |v| options[:haml] = v }
    opt.on("--include-userstamps", "Add t.userstamps to model.") { |v| options[:include_userstamps] = v }
    opt.on("--testunit", "Use test/unit for test files.") { options[:test_framework] = :testunit }
    opt.on("--rspec", "Use RSpec for test files.") { options[:test_framework] = :rspec }
    opt.on("--shoulda", "Use Shoulda for test files.") { options[:test_framework] = :shoulda }
  end

  # is there a better way to do this? Perhaps with const_defined?
  def model_exists?
    File.exist? destination_path("app/models/#{singular_name}.rb")
  end

  def read_template(relative_path)
    ERB.new(File.read(source_path(relative_path)), nil, '-').result(binding)
  end

  def banner
    <<-EOS
    Creates a controller and optional model given the name, actions, and attributes.

    USAGE: #{$0} #{spec.name} ModelName [controller_actions and model:attributes] [options]
    EOS
  end
end
