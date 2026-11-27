require_relative "arbre_string"
require_relative "confirm_dialog"
require_relative "notice"
require_relative "pre_wrap"
require_relative "secret_reveal"
require_relative "status_tag"
require_relative "../views/dropdown_menu"

module ActiveAdminTheme
  module Helpers
    # Every string helper, for a decorator or a plain object outside the views:
    #   include ActiveAdminTheme::Helpers::Tags
    # The object must answer the view methods the components call, such as
    # link_to for dropdown_menu_tag; a Draper decorator can delegate them to
    # `h`.
    module Tags
      include ArbreString
      include ConfirmDialog
      include DropdownMenu
      include Notice
      include PreWrap
      include SecretReveal
      include StatusTag
    end
  end
end
