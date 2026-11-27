module ActiveAdminTheme
  class Engine < ::Rails::Engine
    # ActiveAdmin releases without the layout hooks from activeadmin/activeadmin#9149
    # and #9150 get full copies of the views that render those hooks.
    paths["app/views"] << "app/views_compat" unless ActiveAdminTheme.layout_hooks?

    # Logical paths a Sprockets host must precompile for the theme's modules and
    # the vendored libraries they import (Propshaft hosts need no list).
    def self.sprockets_precompile
      theme = Dir[root.join("app/javascript/active_admin_theme/*.js")].map { |file| "active_admin_theme/#{File.basename(file)}" }
      vendored = Dir[root.join("vendor/javascript/*.js")].map { |file| File.basename(file) }
      (theme + vendored).sort
    end

    # ActiveAdmin keeps its own importmap (ActiveAdmin.importmap) and renders
    # it in the layout, so the theme's modules are pinned there. A host with no
    # importmap-rails has no such config; it imports the npm package instead.
    initializer "active_admin_theme.importmap", after: "active_admin.importmap" do |app|
      next unless app.config.respond_to?(:importmap)

      ActiveAdmin.importmap.draw(root.join("config", "importmap.rb"))
      if app.config.respond_to?(:assets)
        app.config.assets.paths << root.join("app/javascript")
        app.config.assets.paths << root.join("vendor/javascript")
        # Propshaft also has config.assets.precompile, so test for the gem.
        app.config.assets.precompile += self.class.sprockets_precompile if defined?(::Sprockets::Railtie)
      end

      if ActiveAdmin.application.respond_to?(:importmap_watches)
        ActiveAdmin.application.importmap_watches << root.join("app/javascript")
      elsif app.config.importmap.sweep_cache
        # Without importmap_watches (activeadmin/activeadmin#9153) each
        # cache_sweeper(watches:) call replaces the watcher, so rebuild
        # ActiveAdmin's with both directories.
        watches = [ActiveAdmin::Engine.root.join("app/javascript"), root.join("app/javascript")].map(&:to_s)
        app.config.after_initialize { ActiveAdmin.importmap.cache_sweeper(watches: watches) }
      end
    end

    # Host initializers edit ActiveAdminTheme.javascripts, so read it once they
    # have run. Without javascript_modules (activeadmin/activeadmin#9148) the
    # compat _html_head imports the list itself.
    config.after_initialize do
      if ActiveAdmin.application.respond_to?(:javascript_modules)
        ActiveAdmin.application.javascript_modules |= ActiveAdminTheme.javascripts
      end
    end

    # The file leaves ActiveAdmin::ResourceDSL alone when it already has a
    # searchable_select_options, so a host's own definition wins whether it
    # loads before or after this initializer.
    initializer "active_admin_theme.resource_dsl" do
      require "active_admin_theme/resource_dsl/searchable_select"
    end

    initializer "active_admin_theme.config_helper" do
      require "active_admin_theme/helpers/config"
    end

    # Before any resource declares a sidebar.
    initializer "active_admin_theme.sidebar_title" do
      require "active_admin_theme/sidebar_title"
    end

    # Before any resource registers its menu item.
    initializer "active_admin_theme.nested_menu" do
      require "active_admin_theme/nested_menu"
    end

    # Arbre's builder_method defines a method on a shared module, so a host
    # component with the same builder_method name replaces the theme's if it
    # loads later. The engine's to_prepare callback is registered before the
    # host's, so the host's loads later.
    config.to_prepare do
      # Every file under views/ and inputs/ defines Arbre components or
      # formtastic inputs; loading them here keeps their builder methods in
      # place before any resource registers.
      %w[views inputs].each do |dir|
        Dir[File.expand_path("#{dir}/*.rb", __dir__)].sort.each { |file| require file }
      end
    end
  end
end
