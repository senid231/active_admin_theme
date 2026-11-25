module ActiveAdminTheme
  # ActiveAdmin turns a sidebar's name into a String at once, so this records
  # whether it was a Symbol: only a Symbol name is titlecased.
  module SidebarTitle
    def initialize(name, *, &)
      @symbol_name = name.is_a?(Symbol)
      super
    end

    # The translation `active_admin.sidebars.<name>`, else a Symbol name
    # titlecased or a String name as given.
    def display_title
      I18n.t("active_admin.sidebars.#{name.parameterize(separator: '_')}", default: @symbol_name ? name.titlecase : name)
    end
  end
end

ActiveAdmin::SidebarSection.prepend ActiveAdminTheme::SidebarTitle
