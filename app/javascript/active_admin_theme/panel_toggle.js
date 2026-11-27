// Opt-in: add "active_admin_theme/panel_toggle" to ActiveAdminTheme.javascripts.
// A click on a [data-aat-panel-toggle] button (the title of a panel built with
// collapsible: true) flips its aria-expanded and shows or hides the element
// named by aria-controls. Enter and Space work because it is a button. The
// panel dispatches a bubbling "aat:panel:toggle" event with
// detail { panel, expanded }. Panels added later work too.
document.addEventListener("click", (event) => {
  const button = event.target.closest?.("[data-aat-panel-toggle]")
  if (!button) return
  const body = document.getElementById(button.getAttribute("aria-controls"))
  if (!body) return
  const expanded = button.getAttribute("aria-expanded") !== "true"
  button.setAttribute("aria-expanded", String(expanded))
  body.hidden = !expanded
  const panel = button.closest(".panel") || button
  panel.dispatchEvent(new CustomEvent("aat:panel:toggle", { bubbles: true, detail: { panel, expanded } }))
})
